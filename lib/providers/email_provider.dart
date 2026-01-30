import 'package:flutter/material.dart';

import '../models/email_models.dart';
import '../models/folder_models.dart';

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

  Future<void> initialize();
  Future<void> refresh();
  Future<void> selectFolder(String path);
  Future<void> sendMessage({
    EmailThread? thread,
    required String toLine,
    String? ccLine,
    String? bccLine,
    required String subject,
    required String bodyHtml,
    required String bodyText,
  });

  Future<void> saveDraft({
    EmailThread? thread,
    required String toLine,
    String? ccLine,
    String? bccLine,
    required String subject,
    required String bodyHtml,
    required String bodyText,
  });

  Future<String?> archiveThread(EmailThread thread);
}
