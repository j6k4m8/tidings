import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../models/account_models.dart';

// QR transfer format.
//
// The QR code contains only an encrypted v2 envelope. Account credentials are
// never serialized as base64/plain JSON in the QR payload. A separate transfer
// code is shown beside the QR and must be typed on the receiving device.
//
// Envelope:
//   tidings:qrv2:<base64url-json>
//
// Envelope JSON:
// {
//   "v": 2,
//   "alg": "PBKDF2-HS256+A256GCM",
//   "iter": 120000,
//   "exp": <unix-seconds>,
//   "salt": "<base64url>",
//   "nonce": "<base64url>",
//   "ct": "<base64url ciphertext+tag>"
// }
//
// Plaintext JSON, after decrypting with the transfer code:
// {
//   "v": 2,
//   "payloads": [<typed payload json>, ...]
// }

const _kPayloadVersion = 1;
const _kEnvelopeVersion = 2;
const _kEnvelopePrefix = 'tidings:qrv2:';
const _kAlgorithm = 'PBKDF2-HS256+A256GCM';
const _kExpirySeconds = 5 * 60; // 5 minutes
const _kPbkdf2Iterations = 120000;
const _kAesKeyBytes = 32;
const _kSaltBytes = 16;
const _kNonceBytes = 12;
const _kGcmTagBits = 128;
const _kTransferCodeLength = 16;
const _kTransferAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

final _aad = Uint8List.fromList(utf8.encode('tidings-qr-transfer-v2'));

sealed class QrTransferPayload {
  const QrTransferPayload();

  Map<String, dynamic> _toJson();

  static int _exp() =>
      DateTime.now()
          .add(const Duration(seconds: _kExpirySeconds))
          .millisecondsSinceEpoch ~/
      1000;
}

final class QrTransferExport {
  const QrTransferExport({
    required this.qrData,
    required this.transferCode,
    required this.expiresAt,
  });

  final String qrData;
  final String transferCode;
  final DateTime expiresAt;
}

QrTransferExport createQrTransferExport(
  List<QrTransferPayload> payloads, {
  DateTime? now,
  Random? random,
}) {
  if (payloads.isEmpty) {
    throw ArgumentError.value(payloads, 'payloads', 'must not be empty');
  }

  final createdAt = now ?? DateTime.now();
  final expiresAt = createdAt.add(const Duration(seconds: _kExpirySeconds));
  final rng = random ?? Random.secure();
  final transferCode = _generateTransferCode(rng);
  final salt = _randomBytes(_kSaltBytes, rng);
  final nonce = _randomBytes(_kNonceBytes, rng);
  final key = _deriveKey(transferCode, salt);
  final plaintext = utf8.encode(
    jsonEncode({
      'v': _kEnvelopeVersion,
      'payloads': payloads.map((payload) => payload._toJson()).toList(),
    }),
  );
  final ciphertext = _aesGcm(
    encrypt: true,
    key: key,
    nonce: nonce,
    input: Uint8List.fromList(plaintext),
  );
  final envelope = {
    'v': _kEnvelopeVersion,
    'alg': _kAlgorithm,
    'iter': _kPbkdf2Iterations,
    'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
    'salt': _base64UrlNoPadding(salt),
    'nonce': _base64UrlNoPadding(nonce),
    'ct': _base64UrlNoPadding(ciphertext),
  };
  final encodedEnvelope = _base64UrlNoPadding(
    Uint8List.fromList(utf8.encode(jsonEncode(envelope))),
  );
  return QrTransferExport(
    qrData: '$_kEnvelopePrefix$encodedEnvelope',
    transferCode: transferCode,
    expiresAt: expiresAt,
  );
}

bool isEncryptedQrTransfer(String raw) =>
    raw.trim().startsWith(_kEnvelopePrefix);

List<QrTransferPayload>? decodeQrTransferExport(
  String raw, {
  required String transferCode,
  DateTime? now,
}) {
  try {
    final trimmed = raw.trim();
    if (!trimmed.startsWith(_kEnvelopePrefix)) return null;
    final encodedEnvelope = trimmed.substring(_kEnvelopePrefix.length);
    final envelope = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(_decodeBase64Url(encodedEnvelope))) as Map,
    );

    if (envelope['v'] != _kEnvelopeVersion) return null;
    if (envelope['alg'] != _kAlgorithm) return null;
    if (envelope['iter'] != _kPbkdf2Iterations) return null;

    final exp = (envelope['exp'] as num?)?.toInt();
    if (exp == null) return null;
    final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    if ((now ?? DateTime.now()).isAfter(expiry)) return null;

    final salt = _decodeRequiredBytes(envelope['salt']);
    final nonce = _decodeRequiredBytes(envelope['nonce']);
    final ciphertext = _decodeRequiredBytes(envelope['ct']);
    if (salt == null || nonce == null || ciphertext == null) return null;

    final key = _deriveKey(transferCode, salt);
    final plaintext = _aesGcm(
      encrypt: false,
      key: key,
      nonce: nonce,
      input: ciphertext,
    );
    final decoded = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(plaintext)) as Map,
    );
    if (decoded['v'] != _kEnvelopeVersion) return null;

    final rawPayloads = decoded['payloads'];
    if (rawPayloads is! List || rawPayloads.isEmpty) return null;

    final payloads = <QrTransferPayload>[];
    for (final rawPayload in rawPayloads) {
      if (rawPayload is! Map) return null;
      final payload = _payloadFromJson(Map<String, dynamic>.from(rawPayload));
      if (payload == null) return null;
      payloads.add(payload);
    }
    return payloads;
  } catch (_) {
    return null;
  }
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
    'v': _kPayloadVersion,
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
    'v': _kPayloadVersion,
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
    'v': _kPayloadVersion,
    't': 'settings',
    'exp': QrTransferPayload._exp(),
    ...settings,
  };
}

QrTransferPayload? _payloadFromJson(Map<String, dynamic> json) {
  final version = json['v'] as int?;
  if (version != _kPayloadVersion) return null;

  final exp = (json['exp'] as num?)?.toInt();
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
}

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

  static _ImapQrPayload _fromJson(Map<String, dynamic> json) {
    final smtpUseImapCreds = json['smtpUseImapCredentials'] as bool? ?? true;
    return _ImapQrPayload(
      displayName: json['displayName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      server: json['server'] as String? ?? '',
      port: (json['port'] as num?)?.toInt() ?? 993,
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      useTls: json['useTls'] as bool? ?? true,
      smtpServer: json['smtpServer'] as String? ?? '',
      smtpPort: (json['smtpPort'] as num?)?.toInt() ?? 587,
      smtpUsername:
          json['smtpUsername'] as String? ?? json['username'] as String? ?? '',
      smtpPassword: smtpUseImapCreds
          ? (json['password'] as String? ?? '')
          : (json['smtpPassword'] as String? ?? ''),
      smtpUseTls: json['smtpUseTls'] as bool? ?? true,
      smtpUseImapCredentials: smtpUseImapCreds,
      checkMailIntervalMinutes:
          (json['checkMailIntervalMinutes'] as num?)?.toInt() ?? 5,
      crossFolderThreadingEnabled:
          json['crossFolderThreadingEnabled'] as bool? ?? true,
    );
  }
}

final class _GmailQrPayload extends GmailQrPayload {
  const _GmailQrPayload({required super.email});

  static _GmailQrPayload _fromJson(Map<String, dynamic> json) =>
      _GmailQrPayload(email: json['email'] as String? ?? '');
}

final class _SettingsQrPayload extends SettingsQrPayload {
  const _SettingsQrPayload({required super.settings});

  static _SettingsQrPayload _fromJson(Map<String, dynamic> json) {
    final settings = Map<String, Object?>.from(json)
      ..remove('v')
      ..remove('t')
      ..remove('exp');
    return _SettingsQrPayload(settings: settings);
  }
}

String _generateTransferCode(Random random) {
  final raw = List.generate(
    _kTransferCodeLength,
    (_) => _kTransferAlphabet[random.nextInt(_kTransferAlphabet.length)],
  ).join();
  return RegExp(
    '.{1,4}',
  ).allMatches(raw).map((match) => match.group(0)!).join('-');
}

String _normalizeTransferCode(String value) {
  return value
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]'), '')
      .replaceAll('O', '0')
      .replaceAll('I', '1');
}

Uint8List _deriveKey(String transferCode, Uint8List salt) {
  final normalized = _normalizeTransferCode(transferCode);
  if (normalized.length != _kTransferCodeLength) {
    throw const FormatException('Invalid transfer code.');
  }
  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
  derivator.init(Pbkdf2Parameters(salt, _kPbkdf2Iterations, _kAesKeyBytes));
  return derivator.process(Uint8List.fromList(utf8.encode(normalized)));
}

Uint8List _aesGcm({
  required bool encrypt,
  required Uint8List key,
  required Uint8List nonce,
  required Uint8List input,
}) {
  final cipher = GCMBlockCipher(AESEngine());
  cipher.init(
    encrypt,
    AEADParameters(KeyParameter(key), _kGcmTagBits, nonce, _aad),
  );
  return cipher.process(input);
}

Uint8List _randomBytes(int length, Random random) {
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}

String _base64UrlNoPadding(Uint8List bytes) {
  return base64UrlEncode(bytes).replaceAll('=', '');
}

Uint8List _decodeBase64Url(String value) {
  return Uint8List.fromList(base64Url.decode(base64Url.normalize(value)));
}

Uint8List? _decodeRequiredBytes(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return _decodeBase64Url(raw);
}
