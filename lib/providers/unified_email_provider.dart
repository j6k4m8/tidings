import 'dart:async';

import 'package:flutter/material.dart';

import '../models/account_models.dart';
import '../models/email_models.dart';
import '../models/folder_models.dart';
import '../search/search_query.dart';
import '../state/app_state.dart';
import '../state/send_queue.dart';
import 'email_provider.dart';
import '../utils/email_address_utils.dart';

class UnifiedEmailProvider extends EmailProvider {
  UnifiedEmailProvider({required this.appState}) {
    _defaultAccountId = appState.selectedAccount?.id;
    appState.addListener(_handleAppStateChanged);
    _syncProviders();
    unawaited(
      _outboxStore.ensureLoaded().then((_) {
        if (!_disposed) {
          notifyListeners();
        }
      }),
    );
  }

  final AppState appState;
  final Map<String, EmailProvider> _providers = {};
  final Map<String, _ThreadRef> _threadRefs = {};
  final Map<String, _OutboxRef> _outboxRefs = {};
  final OutboxStore _outboxStore = OutboxStore.instance;
  String _selectedFolderPath = 'INBOX';
  String? _defaultAccountId;
  bool _disposed = false;

  @override
  ProviderStatus get status {
    if (_selectedFolderPath == kOutboxFolderPath) {
      return ProviderStatus.ready;
    }
    var hasLoading = false;
    var hasReady = false;
    var hasError = false;
    for (final provider in _providers.values) {
      switch (provider.status) {
        case ProviderStatus.error:
          hasError = true;
          break;
        case ProviderStatus.loading:
          hasLoading = true;
          break;
        case ProviderStatus.ready:
          hasReady = true;
          break;
        case ProviderStatus.idle:
          break;
      }
    }
    if (hasReady) {
      return ProviderStatus.ready;
    }
    if (hasLoading) {
      return ProviderStatus.loading;
    }
    if (hasError) {
      return ProviderStatus.error;
    }
    return ProviderStatus.idle;
  }

  @override
  String? get errorMessage {
    if (_selectedFolderPath == kOutboxFolderPath) {
      return null;
    }
    if (status != ProviderStatus.error) {
      return null;
    }
    for (final provider in _providers.values) {
      if (provider.status == ProviderStatus.error) {
        return provider.errorMessage;
      }
    }
    return null;
  }

  @override
  List<EmailThread> get threads {
    if (_selectedFolderPath == kOutboxFolderPath) {
      return _buildOutboxThreads();
    }
    return _buildThreads();
  }

  @override
  List<EmailMessage> messagesForThread(String threadId) {
    if (_selectedFolderPath == kOutboxFolderPath) {
      final ref = _outboxRefs[threadId] ?? _rebuildOutboxRef(threadId);
      if (ref == null) {
        return const [];
      }
      return [_outboxMessage(ref.item, ref.account, threadId)];
    }
    final ref = _threadRefs[threadId] ?? _rebuildThreadRef(threadId);
    if (ref == null) {
      return const [];
    }
    return ref.provider.messagesForThread(ref.thread.id);
  }

  @override
  EmailMessage? latestMessageForThread(String threadId) {
    if (_selectedFolderPath == kOutboxFolderPath) {
      final ref = _outboxRefs[threadId] ?? _rebuildOutboxRef(threadId);
      if (ref == null) {
        return null;
      }
      return _outboxMessage(ref.item, ref.account, threadId);
    }
    final ref = _threadRefs[threadId] ?? _rebuildThreadRef(threadId);
    if (ref == null) {
      return null;
    }
    return ref.provider.latestMessageForThread(ref.thread.id);
  }

  @override
  List<FolderSection> get folderSections => [
    FolderSection(
      title: 'Mailboxes',
      kind: FolderSectionKind.mailboxes,
      items: [
        const FolderItem(
          index: 0,
          name: 'Inbox',
          path: 'INBOX',
          unreadCount: 0,
          icon: Icons.inbox_rounded,
        ),
        FolderItem(
          index: -1,
          name: 'Outbox',
          path: kOutboxFolderPath,
          unreadCount: outboxCount,
          icon: Icons.outbox_rounded,
        ),
      ],
    ),
  ];

  @override
  int get outboxCount {
    var total = 0;
    for (final account in appState.accounts) {
      total += _outboxStore.itemsForAccount(account.id).length;
    }
    return total;
  }

  @override
  String get selectedFolderPath => _selectedFolderPath;

  @override
  bool isFolderLoading(String path) => false;

  @override
  SearchQuery? get activeSearch =>
      _providers.values.map((p) => p.activeSearch).nonNulls.firstOrNull;

  @override
  bool get isSearchLoading =>
      _providers.values.any((p) => p.isSearchLoading);

  @override
  Future<void> initialize() async {
    for (final provider in _providers.values) {
      if (provider.status == ProviderStatus.idle) {
        await provider.initialize();
      }
    }
  }

  @override
  Future<void> refresh() async {
    for (final provider in _providers.values) {
      await provider.refresh();
    }
  }

  @override
  Future<void> selectFolder(String path) async {
    _selectedFolderPath = path;
    notifyListeners();
  }

  @override
  Future<void> search(SearchQuery? query) async {
    // Fan out to all sub-providers; each manages its own search state.
    await Future.wait(
      _providers.values.map((p) => p.search(query)),
    );
    notifyListeners();
  }

  EmailAccount? accountForThread(String threadId) {
    if (_selectedFolderPath == kOutboxFolderPath) {
      final ref = _outboxRefs[threadId] ?? _rebuildOutboxRef(threadId);
      return ref?.account;
    }
    final ref = _threadRefs[threadId] ?? _rebuildThreadRef(threadId);
    return ref?.account;
  }

  EmailProvider? providerForThread(String threadId) {
    if (_selectedFolderPath == kOutboxFolderPath) {
      final ref = _outboxRefs[threadId] ?? _rebuildOutboxRef(threadId);
      if (ref == null) {
        return null;
      }
      return _providers[ref.account.id];
    }
    final ref = _threadRefs[threadId] ?? _rebuildThreadRef(threadId);
    return ref?.provider;
  }

  EmailProvider? providerForAccount(String accountId) {
    return _providers[accountId];
  }

  String? accountEmailForThread(String threadId) {
    final account = accountForThread(threadId);
    return account?.email;
  }

  @override
  Future<OutboxItem?> sendMessage({
    EmailThread? thread,
    required String toLine,
    String? ccLine,
    String? bccLine,
    required String subject,
    required String bodyHtml,
    required String bodyText,
  }) async {
    if (thread == null) {
      final provider = _providers[_defaultAccountId];
      if (provider != null) {
        return provider.sendMessage(
          toLine: toLine,
          ccLine: ccLine,
          bccLine: bccLine,
          subject: subject,
          bodyHtml: bodyHtml,
          bodyText: bodyText,
        );
      }
      return null;
    }
    final ref = _threadRefs[thread.id] ?? _rebuildThreadRef(thread.id);
    if (ref == null) {
      return null;
    }
    return ref.provider.sendMessage(
      thread: ref.thread,
      toLine: toLine,
      ccLine: ccLine,
      bccLine: bccLine,
      subject: subject,
      bodyHtml: bodyHtml,
      bodyText: bodyText,
    );
  }

  @override
  Future<bool> cancelSend(String outboxId) async {
    await _outboxStore.ensureLoaded();
    final item = _outboxStore.findById(outboxId);
    if (item == null) {
      return false;
    }
    final provider = _providers[item.accountKey];
    if (provider == null) {
      return false;
    }
    return provider.cancelSend(outboxId);
  }

  @override
  Future<void> saveDraft({
    EmailThread? thread,
    required String toLine,
    String? ccLine,
    String? bccLine,
    required String subject,
    required String bodyHtml,
    required String bodyText,
  }) async {
    if (thread == null) {
      final provider = _providers[_defaultAccountId];
      if (provider != null) {
        await provider.saveDraft(
          toLine: toLine,
          ccLine: ccLine,
          bccLine: bccLine,
          subject: subject,
          bodyHtml: bodyHtml,
          bodyText: bodyText,
        );
      }
      return;
    }
    final ref = _threadRefs[thread.id] ?? _rebuildThreadRef(thread.id);
    if (ref == null) {
      return;
    }
    await ref.provider.saveDraft(
      thread: ref.thread,
      toLine: toLine,
      ccLine: ccLine,
      bccLine: bccLine,
      subject: subject,
      bodyHtml: bodyHtml,
      bodyText: bodyText,
    );
  }

  @override
  Future<String?> setThreadUnread(EmailThread thread, bool isUnread) async {
    if (_selectedFolderPath == kOutboxFolderPath) {
      return 'Cannot mark outbox messages.';
    }
    final ref = _threadRefs[thread.id] ?? _rebuildThreadRef(thread.id);
    if (ref == null) {
      return 'Thread not found.';
    }
    return ref.provider.setThreadUnread(ref.thread, isUnread);
  }

  @override
  Future<String?> archiveThread(EmailThread thread) async {
    final ref = _threadRefs[thread.id] ?? _rebuildThreadRef(thread.id);
    if (ref == null) {
      return 'Thread not found.';
    }
    return ref.provider.archiveThread(ref.thread);
  }

  @override
  Future<String?> moveToFolder(
    EmailThread thread,
    String targetPath, {
    EmailMessage? singleMessage,
  }) async {
    final ref = _threadRefs[thread.id] ?? _rebuildThreadRef(thread.id);
    if (ref == null) {
      return 'Thread not found.';
    }
    return ref.provider.moveToFolder(
      ref.thread,
      targetPath,
      singleMessage: singleMessage,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    for (final provider in _providers.values) {
      provider.removeListener(_handleProviderChanged);
    }
    appState.removeListener(_handleAppStateChanged);
    super.dispose();
  }

  void _handleAppStateChanged() {
    if (_disposed) {
      return;
    }
    _defaultAccountId = appState.selectedAccount?.id;
    _syncProviders();
    notifyListeners();
  }

  void _handleProviderChanged() {
    if (_disposed) {
      return;
    }
    notifyListeners();
  }

  void _syncProviders() {
    final activeIds = appState.accounts.map((account) => account.id).toSet();
    final toRemove = _providers.keys.where((id) => !activeIds.contains(id));
    for (final id in toRemove.toList()) {
      _providers[id]?.removeListener(_handleProviderChanged);
      _providers.remove(id);
    }
    for (final account in appState.accounts) {
      final provider = appState.providerForAccount(account.id);
      if (provider == null) {
        continue;
      }
      if (_providers[account.id] == provider) {
        continue;
      }
      _providers[account.id]?.removeListener(_handleProviderChanged);
      _providers[account.id] = provider;
      provider.addListener(_handleProviderChanged);
    }
  }

  List<EmailThread> _buildThreads() {
    _threadRefs.clear();
    final combined = <EmailThread>[];
    for (final account in appState.accounts) {
      final provider = _providers[account.id];
      if (provider == null) {
        continue;
      }
      for (final thread in provider.threads) {
        final unifiedId = _unifiedThreadId(account.id, thread.id);
        final resolvedReceivedAt =
            thread.receivedAt ??
            provider.latestMessageForThread(thread.id)?.receivedAt;
        _threadRefs[unifiedId] = _ThreadRef(
          account: account,
          provider: provider,
          thread: thread,
        );
        combined.add(
          EmailThread(
            id: unifiedId,
            subject: thread.subject,
            participants: thread.participants,
            time: thread.time,
            unread: thread.unread,
            starred: thread.starred,
            receivedAt: resolvedReceivedAt,
          ),
        );
      }
    }
    combined.sort((a, b) {
      final aTime = a.receivedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.receivedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return combined;
  }

  List<EmailThread> _buildOutboxThreads() {
    _outboxRefs.clear();
    final threads = <EmailThread>[];
    for (final account in appState.accounts) {
      final items = _outboxStore.itemsForAccount(account.id);
      for (final item in items) {
        final threadId = _outboxThreadId(account.id, item.id);
        _outboxRefs[threadId] = _OutboxRef(
          account: account,
          item: item,
        );
        final recipients = <EmailAddress>[
          ...splitEmailAddresses(item.toLine),
          ...splitEmailAddresses(item.ccLine ?? ''),
          ...splitEmailAddresses(item.bccLine ?? ''),
        ];
        final createdAt = item.createdAt.toLocal();
        threads.add(
          EmailThread(
            id: threadId,
            subject: item.subject,
            participants: [
              EmailAddress(name: account.displayName, email: account.email),
              ...recipients,
            ],
            time: '',
            unread: false,
            starred: false,
            receivedAt: createdAt,
          ),
        );
      }
    }
    threads.sort((a, b) {
      final aTime = a.receivedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.receivedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return threads;
  }

  _OutboxRef? _rebuildOutboxRef(String threadId) {
    _buildOutboxThreads();
    return _outboxRefs[threadId];
  }

  EmailMessage _outboxMessage(
    OutboxItem item,
    EmailAccount account,
    String threadId,
  ) {
    final to = splitEmailAddresses(item.toLine);
    final cc = splitEmailAddresses(item.ccLine ?? '');
    final bcc = splitEmailAddresses(item.bccLine ?? '');
    final createdAt = item.createdAt.toLocal();
    return EmailMessage(
      id: 'outbox-${item.id}',
      threadId: threadId,
      subject: item.subject,
      from: EmailAddress(name: account.displayName, email: account.email),
      to: to,
      cc: cc,
      bcc: bcc,
      time: '',
      bodyText: item.bodyTextOrNull,
      bodyHtml: item.bodyHtmlOrNull,
      isMe: true,
      isUnread: false,
      receivedAt: createdAt,
      inReplyTo: item.replyMessageId,
      sendStatus: _statusForOutbox(item.status),
    );
  }

  String _outboxThreadId(String accountId, String itemId) {
    return 'outbox-$accountId::$itemId';
  }


  MessageSendStatus _statusForOutbox(OutboxStatus status) {
    switch (status) {
      case OutboxStatus.queued:
        return MessageSendStatus.queued;
      case OutboxStatus.sending:
        return MessageSendStatus.sending;
      case OutboxStatus.failed:
        return MessageSendStatus.failed;
    }
  }

  _ThreadRef? _rebuildThreadRef(String unifiedId) {
    _buildThreads();
    return _threadRefs[unifiedId];
  }

  String _unifiedThreadId(String accountId, String threadId) {
    return '$accountId::$threadId';
  }
}

class _ThreadRef {
  _ThreadRef({
    required this.account,
    required this.provider,
    required this.thread,
  });

  final EmailAccount account;
  final EmailProvider provider;
  final EmailThread thread;
}

class _OutboxRef {
  _OutboxRef({
    required this.account,
    required this.item,
  });

  final EmailAccount account;
  final OutboxItem item;
}
