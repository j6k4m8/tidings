import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Platform-specific options:
//   macOS/iOS — Keychain (with accessibility kSecAttrAccessibleAfterFirstUnlock
//               so background refresh still works after device unlock)
//   Android   — EncryptedSharedPreferences via Keystore
//   Linux     — libsecret / gnome-keyring (when available, falls back to
//               encrypted file in app-private directory)
//
// Windows is intentionally omitted from the current target list.

const _iosOpts = IOSOptions(
  accessibility: KeychainAccessibility.first_unlock,
);
// MacOsOptions with no groupId/accountName — uses the default keychain item
// without requiring the keychain-access-groups entitlement (which needs signing).
const _macOpts = MacOsOptions();
const _androidOpts = AndroidOptions(
  encryptedSharedPreferences: true,
);
const _linuxOpts = LinuxOptions();

FlutterSecureStorage _makeStorage() => const FlutterSecureStorage(
      iOptions: _iosOpts,
      mOptions: _macOpts,
      aOptions: _androidOpts,
      lOptions: _linuxOpts,
    );

// Keys stored per account:
//   tidings.imap.{accountId}.password
//   tidings.imap.{accountId}.smtpPassword  (only when SMTP uses separate creds)
String _imapKey(String id) => 'tidings.imap.$id.password';
String _smtpKey(String id) => 'tidings.imap.$id.smtpPassword';

/// Secure credential storage for IMAP/SMTP passwords.
///
/// Gmail OAuth tokens are handled by the `google_sign_in` SDK via the
/// platform keychain — we don't touch those here.
class CredentialStore {
  CredentialStore._();
  static final CredentialStore instance = CredentialStore._();

  final FlutterSecureStorage _storage = _makeStorage();

  // ── Write ─────────────────────────────────────────────────────────────────

  Future<void> saveImapCredentials({
    required String accountId,
    required String password,
    String? smtpPassword, // null → same as IMAP password (smtpUseImapCredentials)
  }) async {
    try {
      await _storage.write(key: _imapKey(accountId), value: password);
      if (smtpPassword != null && smtpPassword.isNotEmpty) {
        await _storage.write(key: _smtpKey(accountId), value: smtpPassword);
      } else {
        // Remove any previously stored separate SMTP password.
        await _storage.delete(key: _smtpKey(accountId));
      }
    } catch (e) {
      debugPrint('[CredentialStore] saveImapCredentials error: $e');
      rethrow;
    }
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  Future<({String? password, String? smtpPassword})> loadImapCredentials(
    String accountId,
  ) async {
    try {
      final password = await _storage.read(key: _imapKey(accountId));
      final smtpPassword = await _storage.read(key: _smtpKey(accountId));
      return (password: password, smtpPassword: smtpPassword);
    } catch (e) {
      debugPrint('[CredentialStore] loadImapCredentials error: $e');
      return (password: null, smtpPassword: null);
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> deleteImapCredentials(String accountId) async {
    try {
      await _storage.delete(key: _imapKey(accountId));
      await _storage.delete(key: _smtpKey(accountId));
    } catch (e) {
      debugPrint('[CredentialStore] deleteImapCredentials error: $e');
    }
  }
}
