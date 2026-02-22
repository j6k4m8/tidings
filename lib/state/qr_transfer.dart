import 'dart:convert';

import '../models/account_models.dart';

// QR transfer payload format.
//
// The QR code contains a base64url-encoded JSON blob.  Passwords are included
// in plain text — the QR is only valid for 5 minutes (enforced via `exp`), and
// the user has to explicitly choose to show it, so the risk surface is small.
//
// Schema version: 1
//
// IMAP payload:
// {
//   "v": 1,
//   "t": "imap",
//   "exp": <unix-seconds>,
//   "displayName": "...",
//   "email": "...",
//   "server": "...",
//   "port": 993,
//   "username": "...",
//   "password": "...",
//   "useTls": true,
//   "smtpServer": "...",
//   "smtpPort": 587,
//   "smtpUsername": "...",
//   "smtpPassword": "...",      // omitted when smtpUseImapCredentials
//   "smtpUseTls": true,
//   "smtpUseImapCredentials": true,
//   "checkMailIntervalMinutes": 5,
//   "crossFolderThreadingEnabled": true
// }
//
// Gmail payload:
// {
//   "v": 1,
//   "t": "gmail",
//   "exp": <unix-seconds>,
//   "email": "..."
// }
//
// Settings payload (transferable UI preferences only — no layout state,
// no pinned folders, no startup account ID):
// {
//   "v": 1,
//   "t": "settings",
//   "exp": <unix-seconds>,
//   "themeMode": "system" | "light" | "dark",
//   "layoutDensity": "compact" | "standard" | "spacious",
//   "cornerRadiusStyle": "pointy" | "traditional" | "babyProofed",
//   "autoExpandUnread": true,
//   "autoExpandLatest": true,
//   "hideThreadSubjects": false,
//   "hideSelfInThreadList": false,
//   "messageCollapseMode": "maxLines" | "beforeQuotes",
//   "collapsedMaxLines": 6,
//   "showFolderLabels": true,
//   "showFolderUnreadCounts": true,
//   "tintThreadListByAccountAccent": true,
//   "showThreadAccountPill": true,
//   "moveEntireThreadByDefault": true,
//   "showMessageFolderSource": false,
//   "dateOrder": "mdy" | "dmy" | "ymd",
//   "use24HourTime": false
// }

const _kVersion = 1;
const _kExpirySeconds = 5 * 60; // 5 minutes

sealed class QrTransferPayload {
  const QrTransferPayload();

  /// Encode to the QR string (base64url JSON).
  String encode() {
    final json = _toJson();
    final bytes = utf8.encode(jsonEncode(json));
    return base64Url.encode(bytes);
  }

  /// Decode from a QR string.  Returns null if the payload is invalid or expired.
  static QrTransferPayload? decode(String raw) {
    try {
      final bytes = base64Url.decode(base64Url.normalize(raw));
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

      final version = json['v'] as int?;
      if (version != _kVersion) return null;

      final exp = json['exp'] as int?;
      if (exp == null) return null;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      if (DateTime.now().isAfter(expiry)) return null;

      final type = json['t'] as String?;
      return switch (type) {
        'imap' => _ImapQrPayload._fromJson(json),
        'gmail' => _GmailQrPayload._fromJson(json),
        'settings' => _SettingsQrPayload._fromJson(json),
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _toJson();

  static int _exp() =>
      DateTime.now().add(const Duration(seconds: _kExpirySeconds)).millisecondsSinceEpoch ~/
      1000;
}

final class ImapQrPayload extends QrTransferPayload {
  const ImapQrPayload({
    required this.displayName,
    required this.email,
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
    required this.checkMailIntervalMinutes,
    required this.crossFolderThreadingEnabled,
  });

  factory ImapQrPayload.fromAccount(
    EmailAccount account,
    ImapAccountConfig config,
  ) {
    return ImapQrPayload(
      displayName: account.displayName,
      email: account.email,
      server: config.server,
      port: config.port,
      username: config.username,
      password: config.password,
      useTls: config.useTls,
      smtpServer: config.smtpServer,
      smtpPort: config.smtpPort,
      smtpUsername: config.smtpUsername,
      smtpPassword: config.smtpPassword,
      smtpUseTls: config.smtpUseTls,
      smtpUseImapCredentials: config.smtpUseImapCredentials,
      checkMailIntervalMinutes: config.checkMailIntervalMinutes,
      crossFolderThreadingEnabled: config.crossFolderThreadingEnabled,
    );
  }

  final String displayName;
  final String email;
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
  final int checkMailIntervalMinutes;
  final bool crossFolderThreadingEnabled;

  ImapAccountConfig toImapConfig() => ImapAccountConfig(
        server: server,
        port: port,
        username: username,
        password: password,
        useTls: useTls,
        smtpServer: smtpServer,
        smtpPort: smtpPort,
        smtpUsername: smtpUsername,
        smtpPassword: smtpPassword,
        smtpUseTls: smtpUseTls,
        smtpUseImapCredentials: smtpUseImapCredentials,
        checkMailIntervalMinutes: checkMailIntervalMinutes,
        crossFolderThreadingEnabled: crossFolderThreadingEnabled,
      );

  @override
  Map<String, dynamic> _toJson() => {
        'v': _kVersion,
        't': 'imap',
        'exp': QrTransferPayload._exp(),
        'displayName': displayName,
        'email': email,
        'server': server,
        'port': port,
        'username': username,
        'password': password,
        'useTls': useTls,
        'smtpServer': smtpServer,
        'smtpPort': smtpPort,
        'smtpUsername': smtpUsername,
        if (!smtpUseImapCredentials) 'smtpPassword': smtpPassword,
        'smtpUseTls': smtpUseTls,
        'smtpUseImapCredentials': smtpUseImapCredentials,
        'checkMailIntervalMinutes': checkMailIntervalMinutes,
        'crossFolderThreadingEnabled': crossFolderThreadingEnabled,
      };
}

final class GmailQrPayload extends QrTransferPayload {
  const GmailQrPayload({required this.email});

  final String email;

  @override
  Map<String, dynamic> _toJson() => {
        'v': _kVersion,
        't': 'gmail',
        'exp': QrTransferPayload._exp(),
        'email': email,
      };
}

/// Transferable UI preferences.
///
/// Layout state (sidebar collapsed, panel fraction, pinned folders, startup
/// account) is intentionally excluded — those are device-local.
final class SettingsQrPayload extends QrTransferPayload {
  const SettingsQrPayload({required this.settings});

  /// The raw settings map — uses the same key/value format as
  /// [TidingsSettings._settingsToMap], but only the transferable subset.
  final Map<String, Object?> settings;

  @override
  Map<String, dynamic> _toJson() => {
        'v': _kVersion,
        't': 'settings',
        'exp': QrTransferPayload._exp(),
        ...settings,
      };
}

// Private decode helpers.
final class _ImapQrPayload extends ImapQrPayload {
  const _ImapQrPayload({
    required super.displayName,
    required super.email,
    required super.server,
    required super.port,
    required super.username,
    required super.password,
    required super.useTls,
    required super.smtpServer,
    required super.smtpPort,
    required super.smtpUsername,
    required super.smtpPassword,
    required super.smtpUseTls,
    required super.smtpUseImapCredentials,
    required super.checkMailIntervalMinutes,
    required super.crossFolderThreadingEnabled,
  });

  static _ImapQrPayload _fromJson(Map<String, dynamic> j) {
    final smtpUseImapCreds = j['smtpUseImapCredentials'] as bool? ?? true;
    return _ImapQrPayload(
      displayName: j['displayName'] as String? ?? '',
      email: j['email'] as String? ?? '',
      server: j['server'] as String? ?? '',
      port: (j['port'] as num?)?.toInt() ?? 993,
      username: j['username'] as String? ?? '',
      password: j['password'] as String? ?? '',
      useTls: j['useTls'] as bool? ?? true,
      smtpServer: j['smtpServer'] as String? ?? '',
      smtpPort: (j['smtpPort'] as num?)?.toInt() ?? 587,
      smtpUsername: j['smtpUsername'] as String? ?? j['username'] as String? ?? '',
      smtpPassword: smtpUseImapCreds
          ? (j['password'] as String? ?? '')
          : (j['smtpPassword'] as String? ?? ''),
      smtpUseTls: j['smtpUseTls'] as bool? ?? true,
      smtpUseImapCredentials: smtpUseImapCreds,
      checkMailIntervalMinutes: (j['checkMailIntervalMinutes'] as num?)?.toInt() ?? 5,
      crossFolderThreadingEnabled: j['crossFolderThreadingEnabled'] as bool? ?? true,
    );
  }
}

final class _GmailQrPayload extends GmailQrPayload {
  const _GmailQrPayload({required super.email});

  static _GmailQrPayload _fromJson(Map<String, dynamic> j) =>
      _GmailQrPayload(email: j['email'] as String? ?? '');
}

final class _SettingsQrPayload extends SettingsQrPayload {
  const _SettingsQrPayload({required super.settings});

  static _SettingsQrPayload _fromJson(Map<String, dynamic> j) {
    // Strip envelope fields; everything else is settings data.
    final settings = Map<String, Object?>.from(j)
      ..remove('v')
      ..remove('t')
      ..remove('exp');
    return _SettingsQrPayload(settings: settings);
  }
}
