import 'package:flutter/material.dart';

import '../models/account_models.dart';
import '../providers/email_provider.dart';
import '../providers/imap_email_provider.dart';
import '../providers/mock_email_provider.dart';

class AppState extends ChangeNotifier {
  final List<EmailAccount> _accounts = [];
  final Map<String, EmailProvider> _providers = {};
  int _selectedAccountIndex = 0;

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

  Future<void> addMockAccount() async {
    final account = EmailAccount(
      id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
      displayName: 'Jordan',
      email: 'jordan@tidings.dev',
      providerType: EmailProviderType.mock,
    );
    _addAccount(account, MockEmailProvider());
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
    await _initializeCurrentProvider();
    if (provider.status == ProviderStatus.error) {
      _removeAccount(account.id);
      return provider.errorMessage ?? 'Unable to connect to the IMAP server.';
    }
    return null;
  }

  void selectAccount(int index) {
    if (index < 0 || index >= _accounts.length) {
      return;
    }
    _selectedAccountIndex = index;
    notifyListeners();
    _initializeCurrentProvider();
  }

  void removeAccount(String id) {
    _removeAccount(id);
  }

  void _addAccount(EmailAccount account, EmailProvider provider) {
    _accounts.add(account);
    _providers[account.id] = provider;
    _selectedAccountIndex = _accounts.length - 1;
    notifyListeners();
  }

  void _removeAccount(String id) {
    final index = _accounts.indexWhere((account) => account.id == id);
    if (index == -1) {
      return;
    }
    _providers[id]?.dispose();
    _providers.remove(id);
    _accounts.removeAt(index);
    if (_selectedAccountIndex >= _accounts.length) {
      _selectedAccountIndex = _accounts.isEmpty ? 0 : _accounts.length - 1;
    }
    notifyListeners();
  }

  Future<void> _initializeCurrentProvider() async {
    final provider = currentProvider;
    if (provider == null) {
      return;
    }
    await provider.initialize();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final provider in _providers.values) {
      provider.dispose();
    }
    super.dispose();
  }
}
