import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/account_models.dart';
import '../providers/email_provider.dart';
import '../providers/imap_email_provider.dart';
import '../providers/mock_email_provider.dart';

class AppState extends ChangeNotifier {
  static const _accountsStorageKey = 'tidings.accounts';
  static const _selectedAccountKey = 'tidings.selectedAccountId';

  final List<EmailAccount> _accounts = [];
  final Map<String, EmailProvider> _providers = {};
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  SharedPreferences? _prefs;
  int _selectedAccountIndex = 0;
  bool _hasInitialized = false;

  List<EmailAccount> get accounts => List.unmodifiable(_accounts);

  bool get hasAccounts => _accounts.isNotEmpty;

  EmailAccount? get selectedAccount {
    if (_accounts.isEmpty) {
      return null;
    }
    return _accounts[_selectedAccountIndex.clamp(0, _accounts.length - 1)];
  }

  EmailProvider? get currentProvider {
    final account = selectedAccount;
    if (account == null) {
      return null;
    }
    return _providers[account.id];
  }

  Future<void> initialize() async {
    if (_hasInitialized) {
      return;
    }
    _hasInitialized = true;
    final prefs = await _loadPrefs();
    if (prefs == null) {
      return;
    }
    final storedAccounts = prefs.getStringList(_accountsStorageKey) ?? [];
    var needsPersist = false;
    final selectedId = prefs.getString(_selectedAccountKey);
    for (final raw in storedAccounts) {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        needsPersist = true;
        continue;
      }
      final map = decoded.cast<String, Object?>();
      final id = map['id'] as String?;
      if (id == null || id.isEmpty) {
        needsPersist = true;
        continue;
      }
      final providerType = EmailProviderType.values.firstWhere(
        (type) => type.name == map['providerType'],
        orElse: () => EmailProviderType.mock,
      );
      ImapAccountConfig? imapConfig;
      if (providerType == EmailProviderType.imap) {
        final configJson = map['imapConfig'];
        if (configJson is! Map<String, dynamic>) {
          needsPersist = true;
          continue;
        }
        final configMap = configJson.cast<String, Object?>();
        final password = await _readImapPassword(id);
        if (password == null || password.isEmpty) {
          needsPersist = true;
          continue;
        }
        imapConfig = ImapAccountConfig.fromStorageJson(
          configMap,
          password: password,
        );
      }
      final account =
          EmailAccount.fromStorageJson(map, imapConfig: imapConfig);
      final provider = account.providerType == EmailProviderType.imap
          ? ImapEmailProvider(config: imapConfig!, email: account.email)
          : MockEmailProvider();
      _accounts.add(account);
      _providers[account.id] = provider;
    }
    if (_accounts.isNotEmpty && selectedId != null) {
      final index = _accounts.indexWhere((account) => account.id == selectedId);
      if (index != -1) {
        _selectedAccountIndex = index;
      }
    }
    await _initializeCurrentProvider();
    if (needsPersist) {
      await _persistAccounts();
    }
    notifyListeners();
  }

  Future<void> addMockAccount() async {
    final account = EmailAccount(
      id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
      displayName: 'Jordan',
      email: 'jordan@tidings.dev',
      providerType: EmailProviderType.mock,
    );
    _addAccount(account, MockEmailProvider());
    await _persistAccounts();
    await _persistSelectedAccount();
    await _initializeCurrentProvider();
  }

  Future<String?> addImapAccount({
    required String displayName,
    required String email,
    required ImapAccountConfig config,
  }) async {
    final account = EmailAccount(
      id: 'imap-${DateTime.now().millisecondsSinceEpoch}',
      displayName: displayName,
      email: email,
      providerType: EmailProviderType.imap,
      imapConfig: config,
    );
    final provider = ImapEmailProvider(config: config, email: email);
    _addAccount(account, provider);
    await _writeImapPassword(account.id, config.password);
    await _persistAccounts();
    await _persistSelectedAccount();
    await _initializeCurrentProvider();
    if (provider.status == ProviderStatus.error) {
      await removeAccount(account.id);
      return provider.errorMessage ?? 'Unable to connect to the IMAP server.';
    }
    return null;
  }

  Future<void> selectAccount(int index) async {
    if (index < 0 || index >= _accounts.length) {
      return;
    }
    _selectedAccountIndex = index;
    notifyListeners();
    await _persistSelectedAccount();
    await _initializeCurrentProvider();
  }

  Future<void> removeAccount(String id) async {
    final removed = _removeAccountInternal(id);
    if (removed == null) {
      return;
    }
    if (removed.providerType == EmailProviderType.imap) {
      await _deleteImapPassword(removed.id);
    }
    await _persistAccounts();
    await _persistSelectedAccount();
  }

  void _addAccount(EmailAccount account, EmailProvider provider) {
    _accounts.add(account);
    _providers[account.id] = provider;
    _selectedAccountIndex = _accounts.length - 1;
    notifyListeners();
  }

  EmailAccount? _removeAccountInternal(String id) {
    final index = _accounts.indexWhere((account) => account.id == id);
    if (index == -1) {
      return null;
    }
    _providers[id]?.dispose();
    _providers.remove(id);
    final removed = _accounts.removeAt(index);
    if (_selectedAccountIndex >= _accounts.length) {
      _selectedAccountIndex = _accounts.isEmpty ? 0 : _accounts.length - 1;
    }
    notifyListeners();
    return removed;
  }

  Future<void> _initializeCurrentProvider() async {
    final provider = currentProvider;
    if (provider == null) {
      return;
    }
    await provider.initialize();
    notifyListeners();
  }

  Future<SharedPreferences?> _loadPrefs() async {
    if (_prefs != null) {
      return _prefs;
    }
    try {
      _prefs = await SharedPreferences.getInstance();
      return _prefs;
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistAccounts() async {
    final prefs = await _loadPrefs();
    if (prefs == null) {
      return;
    }
    final encoded = _accounts
        .map((account) => jsonEncode(account.toStorageJson()))
        .toList();
    await prefs.setStringList(_accountsStorageKey, encoded);
  }

  Future<void> _persistSelectedAccount() async {
    final prefs = await _loadPrefs();
    if (prefs == null) {
      return;
    }
    final account = selectedAccount;
    if (account == null) {
      await prefs.remove(_selectedAccountKey);
      return;
    }
    await prefs.setString(_selectedAccountKey, account.id);
  }

  String _imapPasswordKey(String accountId) {
    return 'imap.password.$accountId';
  }

  String _imapPasswordPrefsKey(String accountId) {
    return 'imap.password.dev.$accountId';
  }

  Future<String?> _readImapPassword(String accountId) async {
    try {
      return await _secureStorage.read(key: _imapPasswordKey(accountId));
    } catch (_) {
      if (kReleaseMode) {
        return null;
      }
      final prefs = await _loadPrefs();
      return prefs?.getString(_imapPasswordPrefsKey(accountId));
    }
  }

  Future<void> _writeImapPassword(String accountId, String password) async {
    try {
      await _secureStorage.write(
        key: _imapPasswordKey(accountId),
        value: password,
      );
    } catch (_) {
      if (kReleaseMode) {
        return;
      }
      final prefs = await _loadPrefs();
      await prefs?.setString(_imapPasswordPrefsKey(accountId), password);
    }
  }

  Future<void> _deleteImapPassword(String accountId) async {
    try {
      await _secureStorage.delete(key: _imapPasswordKey(accountId));
    } catch (_) {
      if (kReleaseMode) {
        return;
      }
      final prefs = await _loadPrefs();
      await prefs?.remove(_imapPasswordPrefsKey(accountId));
    }
  }

  @override
  void dispose() {
    for (final provider in _providers.values) {
      provider.dispose();
    }
    super.dispose();
  }
}
