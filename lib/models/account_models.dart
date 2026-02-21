import 'package:flutter/material.dart';

enum EmailProviderType {
  mock,
  imap,
  gmail,
}

@immutable
class ImapAccountConfig {
  const ImapAccountConfig({
    required this.server,
    required this.port,
    required this.username,
    required this.password,
    required this.useTls,
    required this.smtpServer,
    required this.smtpPort,
    required this.smtpUsername,
    required this.smtpPassword,
    required this.smtpUseTls,
    required this.smtpUseImapCredentials,
    this.crossFolderThreadingEnabled = false,
    this.checkMailIntervalMinutes = 5,
  });

  final String server;
  final int port;
  final String username;
  final String password;
  final bool useTls;
  final String smtpServer;
  final int smtpPort;
  final String smtpUsername;
  final String smtpPassword;
  final bool smtpUseTls;
  final bool smtpUseImapCredentials;
  final bool crossFolderThreadingEnabled;
  final int checkMailIntervalMinutes;

  Map<String, Object?> toStorageJson() {
    return {
      'server': server,
      'port': port,
      'username': username,
      'useTls': useTls,
      'smtpServer': smtpServer,
      'smtpPort': smtpPort,
      'smtpUsername': smtpUsername,
      'smtpUseTls': smtpUseTls,
      'smtpUseImapCredentials': smtpUseImapCredentials,
      'crossFolderThreadingEnabled': crossFolderThreadingEnabled,
      'checkMailIntervalMinutes': checkMailIntervalMinutes,
    };
  }

  ImapAccountConfig copyWith({
    String? password,
    String? smtpPassword,
    bool? crossFolderThreadingEnabled,
    int? checkMailIntervalMinutes,
  }) {
    return ImapAccountConfig(
      server: server,
      port: port,
      username: username,
      password: password ?? this.password,
      useTls: useTls,
      smtpServer: smtpServer,
      smtpPort: smtpPort,
      smtpUsername: smtpUsername,
      smtpPassword: smtpPassword ?? this.smtpPassword,
      smtpUseTls: smtpUseTls,
      smtpUseImapCredentials: smtpUseImapCredentials,
      crossFolderThreadingEnabled:
          crossFolderThreadingEnabled ?? this.crossFolderThreadingEnabled,
      checkMailIntervalMinutes:
          checkMailIntervalMinutes ?? this.checkMailIntervalMinutes,
    );
  }

  static ImapAccountConfig fromStorageJson(
    Map<String, Object?> json, {
    required String password,
    String? smtpPassword,
  }) {
    final smtpUseImapCredentials =
        json['smtpUseImapCredentials'] as bool? ?? true;
    final username = json['username'] as String? ?? '';
    final rawSmtpUsername = json['smtpUsername'] as String? ?? '';
    final smtpUsername = smtpUseImapCredentials || rawSmtpUsername.isEmpty
        ? username
        : rawSmtpUsername;
    final smtpServer = json['smtpServer'] as String? ?? '';
    final resolvedSmtpServer =
        smtpServer.isEmpty ? (json['server'] as String? ?? '') : smtpServer;
    return ImapAccountConfig(
      server: json['server'] as String? ?? '',
      port: (json['port'] as num?)?.toInt() ?? 993,
      username: username,
      password: password,
      useTls: json['useTls'] as bool? ?? true,
      smtpServer: resolvedSmtpServer,
      smtpPort: (json['smtpPort'] as num?)?.toInt() ?? 587,
      smtpUsername: smtpUsername,
      smtpPassword: smtpUseImapCredentials ? password : (smtpPassword ?? ''),
      smtpUseTls: json['smtpUseTls'] as bool? ?? true,
      smtpUseImapCredentials: smtpUseImapCredentials,
      crossFolderThreadingEnabled:
          json['crossFolderThreadingEnabled'] as bool? ?? false,
      checkMailIntervalMinutes:
          (json['checkMailIntervalMinutes'] as num?)?.toInt() ?? 5,
    );
  }
}

/// Minimal config stored for a Gmail account.  The actual OAuth tokens are
/// managed by the `google_sign_in` SDK in the platform keychain/keystore —
/// this just records the email so we can call `signInSilently` on startup.
@immutable
class GmailAccountConfig {
  const GmailAccountConfig({
    required this.email,
  });

  /// The Google account email, used to disambiguate when multiple Google
  /// accounts are signed in via the platform SDK.
  final String email;

  GmailAccountConfig copyWith({String? email}) {
    return GmailAccountConfig(email: email ?? this.email);
  }

  Map<String, Object?> toStorageJson() => {'email': email};

  static GmailAccountConfig fromStorageJson(Map<String, Object?> json) {
    return GmailAccountConfig(email: json['email'] as String? ?? '');
  }
}

@immutable
class EmailAccount {
  const EmailAccount({
    required this.id,
    required this.displayName,
    required this.email,
    required this.providerType,
    this.imapConfig,
    this.gmailConfig,
    this.accentColorValue,
  });

  final String id;
  final String displayName;
  final String email;
  final EmailProviderType providerType;
  final ImapAccountConfig? imapConfig;
  final GmailAccountConfig? gmailConfig;
  final int? accentColorValue;

  EmailAccount copyWith({
    String? displayName,
    String? email,
    ImapAccountConfig? imapConfig,
    GmailAccountConfig? gmailConfig,
    int? accentColorValue,
  }) {
    return EmailAccount(
      id: id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      providerType: providerType,
      imapConfig: imapConfig ?? this.imapConfig,
      gmailConfig: gmailConfig ?? this.gmailConfig,
      accentColorValue: accentColorValue ?? this.accentColorValue,
    );
  }

  Map<String, Object?> toStorageJson() {
    return {
      'id': id,
      'displayName': displayName,
      'email': email,
      'providerType': providerType.name,
      'imapConfig': imapConfig?.toStorageJson(),
      'gmailConfig': gmailConfig?.toStorageJson(),
      'accentColorValue': accentColorValue,
    };
  }

  static EmailAccount fromStorageJson(
    Map<String, Object?> json, {
    ImapAccountConfig? imapConfig,
    GmailAccountConfig? gmailConfig,
  }) {
    return EmailAccount(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      providerType: EmailProviderType.values.firstWhere(
        (type) => type.name == json['providerType'],
        orElse: () => EmailProviderType.mock,
      ),
      imapConfig: imapConfig,
      gmailConfig: gmailConfig,
      accentColorValue: (json['accentColorValue'] as num?)?.toInt(),
    );
  }
}
