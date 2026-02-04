import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:enough_mail/enough_mail.dart';

import '../models/account_models.dart';
import '../providers/email_provider.dart';
import '../providers/imap_smtp_email_provider.dart';
import '../providers/mock_email_provider.dart';
import 'shortcut_definitions.dart';
import 'config_store.dart';

class AppState extends ChangeNotifier {
  final Random _random = Random();
  final List<EmailAccount> _accounts = [];
  final Map<String, EmailProvider> _providers = {};
  int _selectedAccountIndex = 0;
  bool _hasInitialized = false;
  String? _accentAccountId;
  bool _menuHasThreadSelection = false;
  bool _menuThreadUnread = false;
  void Function(ShortcutAction action)? _menuActionHandler;

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

  String? get accentAccountId => _accentAccountId;

  bool get menuHasThreadSelection => _menuHasThreadSelection;

  bool get menuThreadUnread => _menuThreadUnread;

  bool get hasMenuActionHandler => _menuActionHandler != null;

  void setMenuActionHandler(void Function(ShortcutAction action)? handler) {
    _menuActionHandler = handler;
  }

  void triggerMenuAction(ShortcutAction action) {
    _menuActionHandler?.call(action);
  }

  void updateMenuSelection({
    required bool hasSelection,
    required bool isUnread,
  }) {
    if (_menuHasThreadSelection == hasSelection &&
        _menuThreadUnread == isUnread) {
      return;
    }
    _menuHasThreadSelection = hasSelection;
    _menuThreadUnread = isUnread;
    notifyListeners();
  }

  void setAccentAccountId(String? accountId) {
    if (_accentAccountId == accountId) {
      return;
    }
    _accentAccountId = accountId;
    notifyListeners();
  }

  EmailProvider? providerForAccount(String accountId) {
    return _providers[accountId];
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
        final smtpPassword = _decodePassword(configMap['smtpPasswordB64']);
        imapConfig = ImapAccountConfig.fromStorageJson(
          configMap,
          password: password,
          smtpPassword: smtpPassword,
        );
        if (imapConfig.smtpUseImapCredentials &&
            imapConfig.smtpPassword.isEmpty) {
          imapConfig = imapConfig.copyWith(smtpPassword: imapConfig.password);
        }
      }
      var account = EmailAccount.fromStorageJson(map, imapConfig: imapConfig);
      if (account.accentColorValue == null) {
        account = account.copyWith(accentColorValue: _randomAccentValue());
        needsPersist = true;
      }
      final provider = account.providerType == EmailProviderType.imap
          ? ImapSmtpEmailProvider(
              config: imapConfig!,
              email: account.email,
              accountId: account.id,
            )
          : MockEmailProvider(accountId: account.id);
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
      accentColorValue: _randomAccentValue(),
    );
    _addAccount(account, MockEmailProvider(accountId: account.id));
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
      accentColorValue: _randomAccentValue(),
    );
    final provider = ImapSmtpEmailProvider(
      config: config,
      email: email,
      accountId: account.id,
    );
    _addAccount(account, provider);
    await _persistConfig();
    await _initializeCurrentProvider();
    if (provider.status == ProviderStatus.error) {
      await removeAccount(account.id);
      return provider.errorMessage ?? 'Unable to connect to the IMAP server.';
    }
    return null;
  }

  Future<String?> updateImapAccount({
    required String accountId,
    required String displayName,
    required String email,
    required ImapAccountConfig config,
  }) async {
    final index = _accounts.indexWhere((account) => account.id == accountId);
    if (index == -1) {
      return 'Account not found.';
    }
    final updated = _accounts[index].copyWith(
      displayName: displayName,
      email: email,
      imapConfig: config,
    );
    _accounts[index] = updated;
    _providers[accountId]?.dispose();
    final provider = ImapSmtpEmailProvider(
      config: config,
      email: email,
      accountId: accountId,
    );
    _providers[accountId] = provider;
    await _persistConfig();
    await _initializeCurrentProvider();
    if (provider.status == ProviderStatus.error) {
      return provider.errorMessage ?? 'Unable to connect to the mail server.';
    }
    notifyListeners();
    return null;
  }

  Future<void> setAccountCheckInterval({
    required String accountId,
    required int minutes,
  }) async {
    final index = _accounts.indexWhere((account) => account.id == accountId);
    if (index == -1) {
      return;
    }
    final account = _accounts[index];
    final config = account.imapConfig;
    if (config == null) {
      return;
    }
    final updatedConfig = config.copyWith(checkMailIntervalMinutes: minutes);
    _accounts[index] = account.copyWith(imapConfig: updatedConfig);
    final provider = _providers[accountId];
    if (provider is ImapSmtpEmailProvider) {
      provider.updateInboxRefreshInterval(Duration(minutes: minutes));
    }
    await _persistConfig();
    notifyListeners();
  }

  Future<void> setAccountCrossFolderThreading({
    required String accountId,
    required bool enabled,
  }) async {
    final index = _accounts.indexWhere((account) => account.id == accountId);
    if (index == -1) {
      return;
    }
    final account = _accounts[index];
    final config = account.imapConfig;
    if (config == null) {
      return;
    }
    final updatedConfig = config.copyWith(crossFolderThreadingEnabled: enabled);
    _accounts[index] = account.copyWith(imapConfig: updatedConfig);
    final provider = _providers[accountId];
    if (provider is ImapSmtpEmailProvider) {
      provider.updateCrossFolderThreading(enabled);
    }
    await _persistConfig();
    notifyListeners();
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

  Future<void> setAccountAccentColor(String accountId, Color color) async {
    final index = _accounts.indexWhere((account) => account.id == accountId);
    if (index == -1) {
      return;
    }
    _accounts[index] = _accounts[index].copyWith(
      accentColorValue: color.toARGB32(),
    );
    notifyListeners();
    await _persistConfig();
  }

  Future<void> randomizeAccountAccentColor(String accountId) async {
    final index = _accounts.indexWhere((account) => account.id == accountId);
    if (index == -1) {
      return;
    }
    _accounts[index] = _accounts[index].copyWith(
      accentColorValue: _randomAccentValue(),
    );
    notifyListeners();
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
    final existing = await TidingsConfigStore.loadConfigOrEmpty();
    final payload = <String, Object?>{
      'selectedAccountId': selectedAccount?.id,
      'accounts': _accounts.map((account) {
        final json = account.toStorageJson();
        if (account.providerType == EmailProviderType.imap &&
            account.imapConfig != null) {
          final configJson = Map<String, Object?>.from(
            account.imapConfig!.toStorageJson(),
          );
          configJson['passwordB64'] = base64Encode(
            utf8.encode(account.imapConfig!.password),
          );
          if (!account.imapConfig!.smtpUseImapCredentials &&
              account.imapConfig!.smtpPassword.isNotEmpty) {
            configJson['smtpPasswordB64'] = base64Encode(
              utf8.encode(account.imapConfig!.smtpPassword),
            );
          }
          json['imapConfig'] = configJson;
        }
        return json;
      }).toList(),
    };
    final settings = existing['settings'];
    if (settings is Map) {
      payload['settings'] = settings;
    }
    await TidingsConfigStore.writeConfig(payload);
  }

  Future<Map<String, Object?>?> _loadConfig() async {
    return TidingsConfigStore.loadConfig();
  }

  Future<String?> openConfigDirectory() async {
    final dir = await TidingsConfigStore.configDirectory();
    if (dir == null) {
      return 'Unable to resolve the config directory.';
    }
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [dir.path]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', [dir.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [dir.path]);
      } else {
        return 'Unsupported platform.';
      }
      return null;
    } catch (error) {
      return 'Unable to open config directory: $error';
    }
  }

  int _randomAccentValue() {
    final hue = _random.nextInt(360).toDouble();
    final saturation = 0.6 + _random.nextDouble() * 0.2;
    final lightness = 0.5 + _random.nextDouble() * 0.12;
    return HSLColor.fromAHSL(
      1,
      hue,
      saturation,
      lightness,
    ).toColor().toARGB32();
  }

  Future<ConnectionTestReport> testAccountConnection(
    EmailAccount account,
  ) async {
    if (account.providerType != EmailProviderType.imap ||
        account.imapConfig == null) {
      return const ConnectionTestReport(
        ok: false,
        log: 'No IMAP configuration found.',
      );
    }
    final config = account.imapConfig!;
    final log = StringBuffer();
    final total = Stopwatch()..start();
    final imapClient = ImapClient(isLogEnabled: kDebugMode);
    try {
      final step = Stopwatch()..start();
      await imapClient
          .connectToServer(config.server, config.port, isSecure: config.useTls)
          .timeout(const Duration(seconds: 10));
      step.stop();
      log.writeln('IMAP connect: ${step.elapsedMilliseconds}ms');
      step
        ..reset()
        ..start();
      await imapClient
          .login(config.username, config.password)
          .timeout(const Duration(seconds: 10));
      step.stop();
      log.writeln('IMAP login: ${step.elapsedMilliseconds}ms');
      step
        ..reset()
        ..start();
      await imapClient.logout();
      step.stop();
      log.writeln('IMAP logout: ${step.elapsedMilliseconds}ms');
    } catch (error) {
      total.stop();
      log.writeln('IMAP failed: $error');
      log.writeln('Total: ${total.elapsedMilliseconds}ms');
      return ConnectionTestReport(ok: false, log: log.toString());
    } finally {
      if (imapClient.isConnected) {
        imapClient.disconnect();
      }
    }

    final smtpServer = config.smtpServer.isNotEmpty
        ? config.smtpServer
        : config.server;
    try {
      final step = Stopwatch()..start();
      final greeting = await _probeSmtpGreeting(
        host: smtpServer,
        port: config.smtpPort,
        useImplicitTls: config.smtpPort == 465,
      );
      step.stop();
      log.writeln('SMTP connect: ${step.elapsedMilliseconds}ms');
      if (greeting.isNotEmpty) {
        log.writeln('SMTP greeting: $greeting');
      }
      total.stop();
      log.writeln('Total: ${total.elapsedMilliseconds}ms');
      return ConnectionTestReport(ok: true, log: log.toString());
    } catch (error) {
      total.stop();
      log.writeln('SMTP failed: $error');
      log.writeln('Total: ${total.elapsedMilliseconds}ms');
      return ConnectionTestReport(ok: false, log: log.toString());
    }
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

  Future<String> _probeSmtpGreeting({
    required String host,
    required int port,
    required bool useImplicitTls,
  }) async {
    Socket? socket;
    try {
      socket = useImplicitTls
          ? await SecureSocket.connect(
              host,
              port,
            ).timeout(const Duration(seconds: 10))
          : await Socket.connect(
              host,
              port,
            ).timeout(const Duration(seconds: 10));
      final data = await socket.first.timeout(const Duration(seconds: 8));
      return String.fromCharCodes(data).trim();
    } finally {
      await socket?.close();
    }
  }
}

class ConnectionTestReport {
  const ConnectionTestReport({required this.ok, required this.log});

  final bool ok;
  final String log;
}
