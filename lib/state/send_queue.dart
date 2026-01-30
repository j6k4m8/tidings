import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:yaml/yaml.dart';

import 'config_store.dart';

const String kOutboxFolderPath = 'OUTBOX';

enum OutboxStatus {
  queued,
  sending,
  failed,
}

class OutboxDraft {
  const OutboxDraft({
    required this.accountKey,
    this.threadId,
    required this.toLine,
    this.ccLine,
    this.bccLine,
    required this.subject,
    required this.bodyHtml,
    required this.bodyText,
    this.replyMessageId,
    this.replyInReplyTo,
  });

  final String accountKey;
  final String? threadId;
  final String toLine;
  final String? ccLine;
  final String? bccLine;
  final String subject;
  final String bodyHtml;
  final String bodyText;
  final String? replyMessageId;
  final String? replyInReplyTo;
}

class OutboxItem {
  const OutboxItem({
    required this.id,
    required this.accountKey,
    required this.createdAt,
    required this.status,
    required this.attempts,
    required this.toLine,
    this.ccLine,
    this.bccLine,
    required this.subject,
    required this.bodyHtml,
    required this.bodyText,
    this.threadId,
    this.replyMessageId,
    this.replyInReplyTo,
    this.lastAttemptAt,
    this.nextAttemptAt,
    this.lastError,
  });

  final String id;
  final String accountKey;
  final DateTime createdAt;
  final OutboxStatus status;
  final int attempts;
  final String toLine;
  final String? ccLine;
  final String? bccLine;
  final String subject;
  final String bodyHtml;
  final String bodyText;
  final String? threadId;
  final String? replyMessageId;
  final String? replyInReplyTo;
  final DateTime? lastAttemptAt;
  final DateTime? nextAttemptAt;
  final String? lastError;

  OutboxItem copyWith({
    OutboxStatus? status,
    int? attempts,
    DateTime? lastAttemptAt,
    DateTime? nextAttemptAt,
    String? lastError,
  }) {
    return OutboxItem(
      id: id,
      accountKey: accountKey,
      createdAt: createdAt,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      toLine: toLine,
      ccLine: ccLine,
      bccLine: bccLine,
      subject: subject,
      bodyHtml: bodyHtml,
      bodyText: bodyText,
      threadId: threadId,
      replyMessageId: replyMessageId,
      replyInReplyTo: replyInReplyTo,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, Object?> toStorageMap() {
    return {
      'id': id,
      'accountKey': accountKey,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'attempts': attempts,
      'toLine': toLine,
      if (ccLine != null) 'ccLine': ccLine,
      if (bccLine != null) 'bccLine': bccLine,
      'subject': subject,
      if (bodyHtml.isNotEmpty) 'bodyHtmlB64': _encodeBody(bodyHtml),
      if (bodyText.isNotEmpty) 'bodyTextB64': _encodeBody(bodyText),
      if (threadId != null) 'threadId': threadId,
      if (replyMessageId != null) 'replyMessageId': replyMessageId,
      if (replyInReplyTo != null) 'replyInReplyTo': replyInReplyTo,
      if (lastAttemptAt != null)
        'lastAttemptAt': lastAttemptAt!.toIso8601String(),
      if (nextAttemptAt != null)
        'nextAttemptAt': nextAttemptAt!.toIso8601String(),
      if (lastError != null) 'lastError': lastError,
    };
  }

  static OutboxItem? fromStorageMap(Map<String, Object?> map) {
    final id = map['id'] as String?;
    final accountKey = map['accountKey'] as String?;
    final createdAtRaw = map['createdAt'] as String?;
    if (id == null || accountKey == null || createdAtRaw == null) {
      return null;
    }
    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null) {
      return null;
    }
    final statusRaw = map['status'] as String?;
    final status = OutboxStatus.values.firstWhere(
      (value) => value.name == statusRaw,
      orElse: () => OutboxStatus.queued,
    );
    final attempts = (map['attempts'] as num?)?.toInt() ?? 0;
    final bodyHtml = _decodeBody(map['bodyHtmlB64'] as String?);
    final bodyText = _decodeBody(map['bodyTextB64'] as String?);
    final lastAttemptAt =
        _parseDateTime(map['lastAttemptAt'] as String?);
    final nextAttemptAt =
        _parseDateTime(map['nextAttemptAt'] as String?);
    return OutboxItem(
      id: id,
      accountKey: accountKey,
      createdAt: createdAt,
      status: status,
      attempts: attempts,
      toLine: map['toLine'] as String? ?? '',
      ccLine: map['ccLine'] as String?,
      bccLine: map['bccLine'] as String?,
      subject: map['subject'] as String? ?? '',
      bodyHtml: bodyHtml,
      bodyText: bodyText,
      threadId: map['threadId'] as String?,
      replyMessageId: map['replyMessageId'] as String?,
      replyInReplyTo: map['replyInReplyTo'] as String?,
      lastAttemptAt: lastAttemptAt,
      nextAttemptAt: nextAttemptAt,
      lastError: map['lastError'] as String?,
    );
  }
}

class OutboxStore {
  OutboxStore._();

  static final OutboxStore instance = OutboxStore._();

  final Map<String, List<OutboxItem>> _itemsByAccount = {};
  Future<void>? _loadFuture;
  Future<void> _writeQueue = Future.value();
  bool _loaded = false;

  Future<void> ensureLoaded() {
    if (_loaded) {
      return Future.value();
    }
    _loadFuture ??= _load();
    return _loadFuture!;
  }

  List<OutboxItem> itemsForAccount(String accountKey) {
    final items = _itemsByAccount[accountKey] ?? const [];
    return List<OutboxItem>.from(items);
  }

  Future<void> upsertItem(OutboxItem item) async {
    await ensureLoaded();
    final list = _itemsByAccount.putIfAbsent(item.accountKey, () => []);
    final index = list.indexWhere((existing) => existing.id == item.id);
    if (index == -1) {
      list.add(item);
    } else {
      list[index] = item;
    }
    _scheduleWrite();
  }

  Future<void> removeItem(String accountKey, String id) async {
    await ensureLoaded();
    final list = _itemsByAccount[accountKey];
    if (list == null) {
      return;
    }
    list.removeWhere((item) => item.id == id);
    if (list.isEmpty) {
      _itemsByAccount.remove(accountKey);
    }
    _scheduleWrite();
  }

  Future<void> _load() async {
    try {
      final file = await _outboxFile();
      if (file == null || !await file.exists()) {
        _loaded = true;
        return;
      }
      final raw = await file.readAsString();
      final decoded = loadYaml(raw);
      if (decoded is! YamlMap) {
        _loaded = true;
        return;
      }
      final map = TidingsConfigStore.yamlToMap(decoded);
      final entries = map['entries'];
      if (entries is List) {
        for (final rawEntry in entries) {
          if (rawEntry is! Map) {
            continue;
          }
          final entry = rawEntry.cast<String, Object?>();
          final item = OutboxItem.fromStorageMap(entry);
          if (item == null) {
            continue;
          }
          _itemsByAccount.putIfAbsent(item.accountKey, () => []).add(item);
        }
      }
    } catch (_) {
      // Ignore outbox load failures.
    } finally {
      _loaded = true;
    }
  }

  void _scheduleWrite() {
    _writeQueue = _writeQueue.then((_) => _writeFile());
  }

  Future<void> _writeFile() async {
    try {
      final file = await _outboxFile();
      if (file == null) {
        return;
      }
      final entries = <Map<String, Object?>>[];
      for (final accountEntries in _itemsByAccount.values) {
        for (final item in accountEntries) {
          entries.add(item.toStorageMap());
        }
      }
      final payload = <String, Object?>{
        'entries': entries,
      };
      final yaml = TidingsConfigStore.toYaml(payload);
      await file.writeAsString(yaml);
    } catch (_) {
      // Ignore outbox write failures.
    }
  }

  Future<File?> _outboxFile() async {
    final dir = await TidingsConfigStore.configDirectory();
    if (dir == null) {
      return null;
    }
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/outbox.yml');
  }
}

class SendQueue {
  SendQueue({
    required this.accountKey,
    required this.onChanged,
    required this.sendNow,
    required this.saveDraft,
    OutboxStore? store,
    this.maxRetries = 5,
  }) : _store = store ?? OutboxStore.instance;

  final String accountKey;
  final VoidCallback onChanged;
  final Future<void> Function(OutboxItem item) sendNow;
  final Future<void> Function(OutboxItem item) saveDraft;
  final int maxRetries;
  final OutboxStore _store;
  Timer? _retryTimer;
  bool _processing = false;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    await _store.ensureLoaded();
    await _recoverInFlightItems();
    onChanged();
    _kick();
  }

  List<OutboxItem> get items {
    return _store.itemsForAccount(accountKey);
  }

  int get pendingCount => items.length;

  Future<OutboxItem> enqueue(OutboxDraft draft) async {
    await initialize();
    final now = DateTime.now();
    final item = OutboxItem(
      id: _generateId(now),
      accountKey: draft.accountKey,
      createdAt: now,
      status: OutboxStatus.queued,
      attempts: 0,
      toLine: draft.toLine,
      ccLine: draft.ccLine,
      bccLine: draft.bccLine,
      subject: draft.subject,
      bodyHtml: draft.bodyHtml,
      bodyText: draft.bodyText,
      threadId: draft.threadId,
      replyMessageId: draft.replyMessageId,
      replyInReplyTo: draft.replyInReplyTo,
    );
    await _store.upsertItem(item);
    onChanged();
    _kick();
    return item;
  }

  void dispose() {
    _retryTimer?.cancel();
  }

  void _kick() {
    if (_processing) {
      return;
    }
    unawaited(_process());
  }

  Future<void> _recoverInFlightItems() async {
    final items = _store.itemsForAccount(accountKey);
    var changed = false;
    for (final item in items) {
      if (item.status == OutboxStatus.sending) {
        await _store.upsertItem(
          item.copyWith(status: OutboxStatus.queued),
        );
        changed = true;
      }
    }
    if (changed) {
      onChanged();
    }
  }

  Future<void> _process() async {
    if (_processing) {
      return;
    }
    _processing = true;
    try {
      while (true) {
        final item = _nextItem();
        if (item == null) {
          break;
        }
        // TODO: Add configurable undo delay before attempting send.
        final now = DateTime.now();
        if (item.nextAttemptAt != null &&
            item.nextAttemptAt!.isAfter(now)) {
          _scheduleRetry(item.nextAttemptAt!);
          break;
        }
        if (item.attempts >= maxRetries) {
          await _moveToDrafts(item);
          continue;
        }
        await _sendItem(item);
      }
    } finally {
      _processing = false;
      _scheduleNextAttempt();
    }
  }

  OutboxItem? _nextItem() {
    final pending = items
        .where((item) => item.status != OutboxStatus.sending)
        .toList();
    if (pending.isEmpty) {
      return null;
    }
    final now = DateTime.now();
    final due = pending
        .where(
          (item) =>
              item.nextAttemptAt == null ||
              !item.nextAttemptAt!.isAfter(now),
        )
        .toList();
    if (due.isNotEmpty) {
      due.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return due.first;
    }
    pending.sort((a, b) {
      final aTime = a.nextAttemptAt ?? a.createdAt;
      final bTime = b.nextAttemptAt ?? b.createdAt;
      return aTime.compareTo(bTime);
    });
    return pending.first;
  }

  Future<void> _sendItem(OutboxItem item) async {
    final now = DateTime.now();
    final attempt = item.attempts + 1;
    final inFlight = item.copyWith(
      status: OutboxStatus.sending,
      attempts: attempt,
      lastAttemptAt: now,
      lastError: null,
    );
    await _store.upsertItem(inFlight);
    onChanged();
    try {
      await sendNow(inFlight);
      await _store.removeItem(accountKey, item.id);
      onChanged();
    } catch (error) {
      final delay = _backoffDuration(attempt);
      final retryAt = now.add(delay);
      final next = item.copyWith(
        status: OutboxStatus.queued,
        attempts: attempt,
        lastAttemptAt: now,
        nextAttemptAt: retryAt,
        lastError: error.toString(),
      );
      await _store.upsertItem(next);
      onChanged();
      _scheduleRetry(retryAt);
    }
  }

  Future<void> _moveToDrafts(OutboxItem item) async {
    final now = DateTime.now();
    try {
      await saveDraft(item);
      await _store.removeItem(accountKey, item.id);
      onChanged();
    } catch (error) {
      final retryAt = now.add(const Duration(minutes: 1));
      final next = item.copyWith(
        status: OutboxStatus.failed,
        lastAttemptAt: now,
        nextAttemptAt: retryAt,
        lastError: error.toString(),
      );
      await _store.upsertItem(next);
      onChanged();
      _scheduleRetry(retryAt);
    }
  }

  void _scheduleNextAttempt() {
    final next = _nextItem();
    if (next == null || next.nextAttemptAt == null) {
      return;
    }
    _scheduleRetry(next.nextAttemptAt!);
  }

  void _scheduleRetry(DateTime when) {
    _retryTimer?.cancel();
    final delay = when.difference(DateTime.now());
    if (delay.isNegative) {
      _kick();
      return;
    }
    _retryTimer = Timer(delay, _kick);
  }
}

String _generateId(DateTime now) {
  final random = Random();
  final suffix = random.nextInt(999999).toString().padLeft(6, '0');
  return 'obx-${now.microsecondsSinceEpoch}-$suffix';
}

Duration _backoffDuration(int attempt) {
  const baseSeconds = 5;
  const maxSeconds = 300;
  final delaySeconds =
      min(baseSeconds * pow(2, attempt - 1).toInt(), maxSeconds);
  return Duration(seconds: delaySeconds);
}

String _encodeBody(String value) {
  return base64Encode(utf8.encode(value));
}

String _decodeBody(String? value) {
  if (value == null || value.isEmpty) {
    return '';
  }
  try {
    return utf8.decode(base64Decode(value));
  } catch (_) {
    return '';
  }
}

DateTime? _parseDateTime(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
