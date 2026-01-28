import 'package:flutter/material.dart';

import '../models/account_models.dart';
import '../models/email_models.dart';
import '../models/folder_models.dart';
import '../state/app_state.dart';
import 'email_provider.dart';

class UnifiedEmailProvider extends EmailProvider {
  UnifiedEmailProvider({required this.appState}) {
    _defaultAccountId = appState.selectedAccount?.id;
    appState.addListener(_handleAppStateChanged);
    _syncProviders();
  }

  final AppState appState;
  final Map<String, EmailProvider> _providers = {};
  final Map<String, _ThreadRef> _threadRefs = {};
  String _selectedFolderPath = 'INBOX';
  String? _defaultAccountId;

  @override
  ProviderStatus get status {
    var hasLoading = false;
    var hasReady = false;
    for (final provider in _providers.values) {
      switch (provider.status) {
        case ProviderStatus.error:
          return ProviderStatus.error;
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
    if (hasLoading) {
      return ProviderStatus.loading;
    }
    if (hasReady) {
      return ProviderStatus.ready;
    }
    return ProviderStatus.idle;
  }

  @override
  String? get errorMessage {
    for (final provider in _providers.values) {
      if (provider.status == ProviderStatus.error) {
        return provider.errorMessage;
      }
    }
    return null;
  }

  @override
  List<EmailThread> get threads => _buildThreads();

  @override
  List<EmailMessage> messagesForThread(String threadId) {
    final ref = _threadRefs[threadId] ?? _rebuildThreadRef(threadId);
    if (ref == null) {
      return const [];
    }
    return ref.provider.messagesForThread(ref.thread.id);
  }

  @override
  EmailMessage? latestMessageForThread(String threadId) {
    final ref = _threadRefs[threadId] ?? _rebuildThreadRef(threadId);
    if (ref == null) {
      return null;
    }
    return ref.provider.latestMessageForThread(ref.thread.id);
  }

  @override
  List<FolderSection> get folderSections => const [
        FolderSection(
          title: 'Mailboxes',
          kind: FolderSectionKind.mailboxes,
          items: [
            FolderItem(
              index: 0,
              name: 'Inbox',
              path: 'INBOX',
              unreadCount: 0,
              icon: Icons.inbox_rounded,
            ),
          ],
        ),
      ];

  @override
  String get selectedFolderPath => _selectedFolderPath;

  @override
  bool isFolderLoading(String path) => false;

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

  EmailAccount? accountForThread(String threadId) {
    final ref = _threadRefs[threadId] ?? _rebuildThreadRef(threadId);
    return ref?.account;
  }

  EmailProvider? providerForThread(String threadId) {
    final ref = _threadRefs[threadId] ?? _rebuildThreadRef(threadId);
    return ref?.provider;
  }

  String? accountEmailForThread(String threadId) {
    final account = accountForThread(threadId);
    return account?.email;
  }

  @override
  Future<void> sendMessage({
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
        await provider.sendMessage(
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
    await ref.provider.sendMessage(
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
  Future<String?> archiveThread(EmailThread thread) async {
    final ref = _threadRefs[thread.id] ?? _rebuildThreadRef(thread.id);
    if (ref == null) {
      return 'Thread not found.';
    }
    return ref.provider.archiveThread(ref.thread);
  }

  @override
  void dispose() {
    for (final provider in _providers.values) {
      provider.removeListener(_handleProviderChanged);
    }
    appState.removeListener(_handleAppStateChanged);
    super.dispose();
  }

  void _handleAppStateChanged() {
    _defaultAccountId = appState.selectedAccount?.id;
    _syncProviders();
    notifyListeners();
  }

  void _handleProviderChanged() {
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
            receivedAt: thread.receivedAt,
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
