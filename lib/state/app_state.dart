import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/account_models.dart';
import '../providers/email_provider.dart';
import '../providers/imap_email_provider.dart';
import '../providers/mock_email_provider.dart';

class AppState extends ChangeNotifier {
  final List<EmailAccount> _accounts = [];
  final Map<String, EmailProvider> _providers = {};
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
    final config = await _loadConfig();
    if (config == null) {
      return;
    }
    final storedAccounts = config['accounts'];
    if (storedAccounts is! List) {
      return;
    }
    var needsPersist = false;
    final selectedId = config['selectedAccountId'] as String?;
    for (final raw in storedAccounts) {
      if (raw is! Map<String, dynamic>) {
        needsPersist = true;
        continue;
      }
      final map = raw.cast<String, Object?>();
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
        final password = _decodePassword(configMap['passwordB64']);
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
      await _persistConfig();
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
    await _persistConfig();
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
    await _persistConfig();
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
    await _persistConfig();
    await _initializeCurrentProvider();
  }

  Future<void> removeAccount(String id) async {
    final removed = _removeAccountInternal(id);
    if (removed == null) {
      return;
    }
    await _persistConfig();
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

  Future<void> _persistConfig() async {
    final file = await _configFile();
    if (file == null) {
      return;
    }
    final payload = <String, Object?>{
      'selectedAccountId': selectedAccount?.id,
      'accounts': _accounts.map((account) {
        final json = account.toStorageJson();
        if (account.providerType == EmailProviderType.imap &&
            account.imapConfig != null) {
          final configJson = Map<String, Object?>.from(
            account.imapConfig!.toStorageJson(),
          );
          configJson['passwordB64'] =
              base64Encode(utf8.encode(account.imapConfig!.password));
          json['imapConfig'] = configJson;
        }
        return json;
      }).toList(),
    };
    await _writeConfig(file, payload);
  }

  Future<Map<String, Object?>?> _loadConfig() async {
    final file = await _configFile();
    if (file == null) {
      return null;
    }
    if (!await file.exists()) {
      return null;
    }
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return decoded.cast<String, Object?>();
    } catch (_) {
      return null;
    }
  }

  Future<File?> _configFile() async {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'];
    if (home == null || home.isEmpty) {
      return null;
    }
    final dir = Directory('$home/.config');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/tidings.yml');
  }

  Future<void> _writeConfig(File file, Map<String, Object?> payload) async {
    final encoder = const JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(payload));
  }

  String? _decodePassword(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      return null;
    }
    try {
      return utf8.decode(base64Decode(raw));
    } catch (_) {
      return null;
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
