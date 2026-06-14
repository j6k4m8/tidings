import 'package:flutter/material.dart';

import '../models/email_models.dart';
import '../models/folder_models.dart';
import '../search/search_query.dart';
import '../state/send_queue.dart';

enum ProviderStatus {
  idle,
  loading,
  ready,
  error,
}

abstract class EmailProvider extends ChangeNotifier {
  ProviderStatus get status;
  String? get errorMessage;

  List<EmailThread> get threads;
  List<EmailMessage> messagesForThread(String threadId);
  EmailMessage? latestMessageForThread(String threadId);
  int get outboxCount;
  List<FolderSection> get folderSections;
  String get selectedFolderPath;
  bool isFolderLoading(String path);

  // ── Search ──────────────────────────────────────────────────────────────

  /// The active search query, or null if not in search mode.
  SearchQuery? get activeSearch;

  /// True when a server-side search is in progress.
  bool get isSearchLoading;

  /// Executes [query] as a server search and switches to the search pseudo-folder.
  /// Pass null to clear the search and return to the previous folder.
  Future<void> search(SearchQuery? query);

  // ── Folder navigation ────────────────────────────────────────────────────

  Future<void> initialize();
  Future<void> refresh();
  Future<void> selectFolder(String path);
  Future<OutboxItem?> sendMessage({
    EmailThread? thread,
    required String toLine,
    String? ccLine,
    String? bccLine,
    required String subject,
    required String bodyHtml,
    required String bodyText,
  });

  Future<bool> cancelSend(String outboxId);

  Future<void> saveDraft({
    EmailThread? thread,
    required String toLine,
    String? ccLine,
    String? bccLine,
    required String subject,
    required String bodyHtml,
    required String bodyText,
  });

  Future<String?> setThreadUnread(EmailThread thread, bool isUnread);

  Future<String?> archiveThread(EmailThread thread);

  /// Moves the thread to Trash. Returns null on success or an error message.
  Future<String?> deleteThread(EmailThread thread);

  Future<String?> moveToFolder(
    EmailThread thread,
    String targetPath, {
    EmailMessage? singleMessage,
  });

  /// Optimistically removes [thread] from the list and returns a handle whose
  /// effect is deferred so it can be undone. Nothing is sent to the server
  /// until [PendingThreadMutation.commit]; [PendingThreadMutation.undo]
  /// restores the thread instead.
  PendingThreadMutation beginArchive(EmailThread thread);

  /// As [beginArchive] but moves the whole thread to [targetPath].
  PendingThreadMutation beginMoveToFolder(EmailThread thread, String targetPath);
}

/// A thread mutation (archive / move) that has been applied optimistically —
/// the thread is already hidden — but whose server-side effect is deferred so
/// the user can undo it. Either [commit] or [undo] runs exactly once; the other
/// becomes a no-op.
class PendingThreadMutation {
  PendingThreadMutation({
    required Future<String?> Function() onCommit,
    required VoidCallback onUndo,
  }) : _onCommit = onCommit,
       _onUndo = onUndo;

  final Future<String?> Function() _onCommit;
  final VoidCallback _onUndo;
  bool _settled = false;

  /// Performs the deferred operation for real. Returns null on success or an
  /// error message. Returns null without acting once already settled.
  Future<String?> commit() async {
    if (_settled) {
      return null;
    }
    _settled = true;
    return _onCommit();
  }

  /// Restores the optimistically-removed thread. No-op once already settled.
  void undo() {
    if (_settled) {
      return;
    }
    _settled = true;
    _onUndo();
  }
}
