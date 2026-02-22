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

  Future<String?> moveToFolder(
    EmailThread thread,
    String targetPath, {
    EmailMessage? singleMessage,
  });
}
