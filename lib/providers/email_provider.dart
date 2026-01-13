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
  List<FolderSection> get folderSections;
  String get selectedFolderPath;

  Future<void> initialize();
  Future<void> refresh();
  Future<void> selectFolder(String path);
}
