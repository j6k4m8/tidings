import 'package:flutter/material.dart';

import '../models/account_models.dart';
import '../state/app_state.dart';
import '../theme/color_tokens.dart';
import '../theme/glass.dart';
import '../widgets/accent_switch.dart';
import '../widgets/tidings_background.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({
    super.key,
    required this.appState,
    required this.accent,
  });

  final AppState appState;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TidingsBackground(
        accent: accent,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: GlassPanel(
              borderRadius: BorderRadius.circular(28),
              padding: const EdgeInsets.all(24),
              variant: GlassVariant.sheet,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to Tidings',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connect your email or start with a mock inbox.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ColorTokens.textSecondary(context),
                        ),
                  ),
                  const SizedBox(height: 24),
                  _OnboardingCard(
                    title: 'Connect IMAP',
                    subtitle:
                        'Bring your real mailbox into Tidings with IMAP sync.',
                    cta: 'Add IMAP account',
                    accent: accent,
                    onTap: () => showAccountSetupSheet(
                      context,
                      appState: appState,
                      accent: accent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _OnboardingCard(
                    title: 'Try the mock inbox',
                    subtitle:
                        'Explore Tidings with sample threads and UI flows.',
                    cta: 'Use mock data',
                    accent: accent,
                    onTap: appState.addMockAccount,
                    subtle: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.accent,
    required this.onTap,
    this.subtle = false,
  });

  final String title;
  final String subtitle;
  final String cta;
  final Color accent;
  final VoidCallback onTap;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: subtle
            ? ColorTokens.cardFill(context, 0.06)
            : accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: subtle ? ColorTokens.border(context, 0.12) : accent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ColorTokens.textSecondary(context),
                ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: onTap,
              child: Text(cta),
            ),
          ),
        ],
      ),
    );
  }
}

void showAccountSetupSheet(
  BuildContext context, {
  required AppState appState,
  required Color accent,
}) {
  final isCompact = MediaQuery.of(context).size.width < 720;
  if (isCompact) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccountSetupSheet(
        appState: appState,
        accent: accent,
        isSheet: true,
      ),
    );
    return;
  }
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: _AccountSetupSheet(
          appState: appState,
          accent: accent,
          isSheet: false,
        ),
      ),
    ),
  );
}

void showAccountPickerSheet(
  BuildContext context, {
  required AppState appState,
  required Color accent,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AccountPickerSheet(
      appState: appState,
      accent: accent,
    ),
  );
}

void showAccountEditSheet(
  BuildContext context, {
  required AppState appState,
  required EmailAccount account,
  required Color accent,
}) {
  final isCompact = MediaQuery.of(context).size.width < 720;
  if (isCompact) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccountEditSheet(
        appState: appState,
        account: account,
        accent: accent,
        isSheet: true,
      ),
    );
    return;
  }
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: _AccountEditSheet(
          appState: appState,
          account: account,
          accent: accent,
          isSheet: false,
        ),
      ),
    ),
  );
}

class _AccountPickerSheet extends StatelessWidget {
  const _AccountPickerSheet({
    required this.appState,
    required this.accent,
  });

  final AppState appState;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GlassPanel(
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(16),
          variant: GlassVariant.sheet,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Accounts', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ...appState.accounts.asMap().entries.map((entry) {
                final isSelected =
                    appState.selectedAccount?.id == entry.value.id;
                return ListTile(
                  title: Text(entry.value.displayName),
                  subtitle: Text(entry.value.email),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: accent)
                      : null,
                  onTap: () {
                    appState.selectAccount(entry.key);
                    Navigator.of(context).pop();
                  },
                );
              }),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  showAccountSetupSheet(
                    context,
                    appState: appState,
                    accent: accent,
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Add account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountSetupSheet extends StatefulWidget {
  const _AccountSetupSheet({
    required this.appState,
    required this.accent,
    required this.isSheet,
  });

  final AppState appState;
  final Color accent;
  final bool isSheet;

  @override
  State<_AccountSetupSheet> createState() => _AccountSetupSheetState();
}

class _AccountEditSheet extends StatefulWidget {
  const _AccountEditSheet({
    required this.appState,
    required this.account,
    required this.accent,
    required this.isSheet,
  });

  final AppState appState;
  final EmailAccount account;
  final Color accent;
  final bool isSheet;

  @override
  State<_AccountEditSheet> createState() => _AccountEditSheetState();
}

class _AccountEditSheetState extends State<_AccountEditSheet> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _serverController;
  late final TextEditingController _portController;
  late final TextEditingController _usernameController;
  final _passwordController = TextEditingController();
  late final TextEditingController _smtpServerController;
  late final TextEditingController _smtpPortController;
  late final TextEditingController _smtpUsernameController;
  final _smtpPasswordController = TextEditingController();
  bool _useTls = true;
  bool _smtpUseTls = true;
  bool _smtpUseImapAuth = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _smtpAutoHost;

  @override
  void initState() {
    super.initState();
    final config = widget.account.imapConfig!;
    _displayNameController =
        TextEditingController(text: widget.account.displayName);
    _emailController = TextEditingController(text: widget.account.email);
    _serverController = TextEditingController(text: config.server);
    _portController = TextEditingController(text: config.port.toString());
    _usernameController = TextEditingController(text: config.username);
    _smtpServerController = TextEditingController(text: config.smtpServer);
    _smtpPortController = TextEditingController(text: config.smtpPort.toString());
    _smtpUsernameController = TextEditingController(text: config.smtpUsername);
    _useTls = config.useTls;
    _smtpUseTls = config.smtpUseTls;
    _smtpUseImapAuth = config.smtpUseImapCredentials;
    _smtpAutoHost = _autoDetectSmtpHost(_serverController.text.trim());
    _serverController.addListener(_handleImapServerChange);
    _passwordController.addListener(_handlePasswordChange);
    _smtpPasswordController.addListener(_handlePasswordChange);
  }

  @override
  void dispose() {
    _serverController.removeListener(_handleImapServerChange);
    _passwordController.removeListener(_handlePasswordChange);
    _smtpPasswordController.removeListener(_handlePasswordChange);
    _displayNameController.dispose();
    _emailController.dispose();
    _serverController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _smtpServerController.dispose();
    _smtpPortController.dispose();
    _smtpUsernameController.dispose();
    _smtpPasswordController.dispose();
    super.dispose();
  }

  void _handleImapServerChange() {
    final nextImap = _serverController.text.trim();
    final nextAuto = _autoDetectSmtpHost(nextImap);
    final currentSmtp = _smtpServerController.text.trim();
    if (currentSmtp.isEmpty ||
        (_smtpAutoHost != null && currentSmtp == _smtpAutoHost)) {
      if (nextAuto != null && nextAuto != currentSmtp) {
        _smtpServerController.text = nextAuto;
      }
    }
    _smtpAutoHost = nextAuto;
  }

  void _handlePasswordChange() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _save() async {
    final displayName = _displayNameController.text.trim();
    final email = _emailController.text.trim();
    final server = _serverController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final smtpServer = _smtpServerController.text.trim();
    final smtpUsername = _smtpUsernameController.text.trim();
    final smtpPassword = _smtpPasswordController.text;

    if (displayName.isEmpty ||
        email.isEmpty ||
        server.isEmpty ||
        username.isEmpty ||
        password.isEmpty ||
        smtpServer.isEmpty ||
        (!_smtpUseImapAuth && (smtpUsername.isEmpty || smtpPassword.isEmpty))) {
      setState(() {
        _errorMessage = 'Please fill in all required fields.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final port = int.tryParse(_portController.text.trim()) ?? 993;
    final smtpPort = int.tryParse(_smtpPortController.text.trim()) ?? 587;
    final effectiveSmtpUsername =
        _smtpUseImapAuth ? username : smtpUsername;
    final effectiveSmtpPassword = _smtpUseImapAuth ? password : smtpPassword;
    final config = ImapAccountConfig(
      server: server,
      port: port,
      username: username,
      password: password,
      useTls: _useTls,
      smtpServer: smtpServer,
      smtpPort: smtpPort,
      smtpUsername: effectiveSmtpUsername,
      smtpPassword: effectiveSmtpPassword,
      smtpUseTls: _smtpUseTls,
      smtpUseImapCredentials: _smtpUseImapAuth,
    );
    final error = await widget.appState.updateImapAccount(
      accountId: widget.account.id,
      displayName: displayName,
      email: email,
      config: config,
    );
    if (!mounted) {
      return;
    }
    if (error != null) {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    final padding = widget.isSheet
        ? EdgeInsets.fromLTRB(16, 16, 16, 16 + insets.bottom)
        : EdgeInsets.only(bottom: insets.bottom);
    return SafeArea(
      child: Padding(
        padding: padding,
        child: GlassPanel(
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(16),
          variant: GlassVariant.sheet,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit IMAP account',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                _LabeledField(
                  label: 'Display name',
                  controller: _displayNameController,
                  hintText: 'Jordan',
                ),
                _LabeledField(
                  label: 'Email',
                  controller: _emailController,
                  hintText: 'jordan@tidings.dev',
                ),
                _LabeledField(
                  label: 'IMAP server',
                  controller: _serverController,
                  hintText: 'imap.example.com',
                ),
                Row(
                  children: [
                    Expanded(
                      child: _LabeledField(
                        label: 'Port',
                        controller: _portController,
                        hintText: '993',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LabeledField(
                        label: 'Username',
                        controller: _usernameController,
                        hintText: 'jordan',
                      ),
                    ),
                  ],
                ),
                _LabeledField(
                  label: 'Password',
                  controller: _passwordController,
                  hintText: '',
                  obscureText: true,
                ),
                if (_passwordController.text.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Password required to save.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.redAccent,
                          ),
                    ),
                  ),
                _ToggleRow(
                  title: 'Use TLS',
                  accent: widget.accent,
                  value: _useTls,
                  onChanged: (value) => setState(() => _useTls = value),
                ),
                const SizedBox(height: 8),
                Text('SMTP', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _LabeledField(
                  label: 'SMTP server',
                  controller: _smtpServerController,
                  hintText: 'smtp.example.com',
                ),
                Row(
                  children: [
                    Expanded(
                      child: _LabeledField(
                        label: 'Port',
                        controller: _smtpPortController,
                        hintText: '587',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ToggleRow(
                        title: 'Use TLS',
                        accent: widget.accent,
                        value: _smtpUseTls,
                        onChanged: (value) =>
                            setState(() => _smtpUseTls = value),
                      ),
                    ),
                  ],
                ),
                _ToggleRow(
                  title: 'Use IMAP credentials',
                  accent: widget.accent,
                  value: _smtpUseImapAuth,
                  onChanged: (value) =>
                      setState(() => _smtpUseImapAuth = value),
                ),
                const SizedBox(height: 8),
                _AuthFields(
                  enabled: !_smtpUseImapAuth,
                  child: Column(
                    children: [
                      _LabeledField(
                        label: 'SMTP username',
                        controller: _smtpUsernameController,
                        hintText: 'jordan',
                      ),
                      _LabeledField(
                        label: 'SMTP password',
                        controller: _smtpPasswordController,
                        hintText: '',
                        obscureText: true,
                      ),
                      if (!_smtpUseImapAuth &&
                          _smtpPasswordController.text.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'SMTP password required to save.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.redAccent,
                                    ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.redAccent,
                        ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _isLoading ? null : _save,
                      child: _isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountSetupSheetState extends State<_AccountSetupSheet> {
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _serverController = TextEditingController();
  final _portController = TextEditingController(text: '993');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _smtpServerController = TextEditingController();
  final _smtpPortController = TextEditingController(text: '587');
  final _smtpUsernameController = TextEditingController();
  final _smtpPasswordController = TextEditingController();
  bool _useTls = true;
  bool _smtpUseTls = true;
  bool _smtpUseImapAuth = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _smtpAutoHost;

  @override
  void dispose() {
    _serverController.removeListener(_handleImapServerChange);
    _displayNameController.dispose();
    _emailController.dispose();
    _serverController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _smtpServerController.dispose();
    _smtpPortController.dispose();
    _smtpUsernameController.dispose();
    _smtpPasswordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _smtpAutoHost = _autoDetectSmtpHost(_serverController.text.trim());
    if (_smtpServerController.text.trim().isEmpty && _smtpAutoHost != null) {
      _smtpServerController.text = _smtpAutoHost!;
    }
    _serverController.addListener(_handleImapServerChange);
  }

  void _handleImapServerChange() {
    final nextImap = _serverController.text.trim();
    final nextAuto = _autoDetectSmtpHost(nextImap);
    final currentSmtp = _smtpServerController.text.trim();
    if (currentSmtp.isEmpty ||
        (_smtpAutoHost != null && currentSmtp == _smtpAutoHost)) {
      if (nextAuto != null && nextAuto != currentSmtp) {
        _smtpServerController.text = nextAuto;
      }
    }
    _smtpAutoHost = nextAuto;
  }

  Future<void> _connect() async {
    final displayName = _displayNameController.text.trim();
    final email = _emailController.text.trim();
    final server = _serverController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final smtpServer = _smtpServerController.text.trim();
    final smtpUsername = _smtpUsernameController.text.trim();
    final smtpPassword = _smtpPasswordController.text;
    if (displayName.isEmpty ||
        email.isEmpty ||
        server.isEmpty ||
        username.isEmpty ||
        password.isEmpty ||
        smtpServer.isEmpty ||
        (!_smtpUseImapAuth && (smtpUsername.isEmpty || smtpPassword.isEmpty))) {
      setState(() {
        _errorMessage = 'Please fill in all required fields.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final port = int.tryParse(_portController.text.trim()) ?? 993;
    final smtpPort = int.tryParse(_smtpPortController.text.trim()) ?? 587;
    final effectiveSmtpUsername =
        _smtpUseImapAuth ? username : smtpUsername;
    final effectiveSmtpPassword = _smtpUseImapAuth ? password : smtpPassword;
    final config = ImapAccountConfig(
      server: server,
      port: port,
      username: username,
      password: password,
      useTls: _useTls,
      smtpServer: smtpServer,
      smtpPort: smtpPort,
      smtpUsername: effectiveSmtpUsername,
      smtpPassword: effectiveSmtpPassword,
      smtpUseTls: _smtpUseTls,
      smtpUseImapCredentials: _smtpUseImapAuth,
    );
    final error = await widget.appState.addImapAccount(
      displayName: displayName,
      email: email,
      config: config,
    );
    if (!mounted) {
      return;
    }
    if (error != null) {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    final padding = widget.isSheet
        ? EdgeInsets.fromLTRB(16, 16, 16, 16 + insets.bottom)
        : EdgeInsets.only(bottom: insets.bottom);
    return SafeArea(
      child: Padding(
        padding: padding,
        child: GlassPanel(
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(16),
          variant: GlassVariant.sheet,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add IMAP account',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                _LabeledField(
                  label: 'Display name',
                  controller: _displayNameController,
                  hintText: 'Jordan',
                ),
                _LabeledField(
                  label: 'Email',
                  controller: _emailController,
                  hintText: 'jordan@tidings.dev',
                ),
                _LabeledField(
                  label: 'IMAP server',
                  controller: _serverController,
                  hintText: 'imap.example.com',
                ),
                Row(
                  children: [
                    Expanded(
                      child: _LabeledField(
                        label: 'Port',
                        controller: _portController,
                        hintText: '993',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LabeledField(
                        label: 'Username',
                        controller: _usernameController,
                        hintText: 'jordan',
                      ),
                    ),
                  ],
                ),
                _LabeledField(
                  label: 'Password',
                  controller: _passwordController,
                  hintText: '••••••••',
                  obscureText: true,
                ),
                _ToggleRow(
                  title: 'Use TLS',
                  accent: widget.accent,
                  value: _useTls,
                  onChanged: (value) => setState(() => _useTls = value),
                ),
                const SizedBox(height: 8),
                Text('SMTP', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _LabeledField(
                  label: 'SMTP server',
                  controller: _smtpServerController,
                  hintText: 'smtp.example.com',
                ),
                Row(
                  children: [
                    Expanded(
                      child: _LabeledField(
                        label: 'Port',
                        controller: _smtpPortController,
                        hintText: '587',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ToggleRow(
                        title: 'Use TLS',
                        accent: widget.accent,
                        value: _smtpUseTls,
                        onChanged: (value) =>
                            setState(() => _smtpUseTls = value),
                      ),
                    ),
                  ],
                ),
                _ToggleRow(
                  title: 'Use IMAP credentials',
                  accent: widget.accent,
                  value: _smtpUseImapAuth,
                  onChanged: (value) =>
                      setState(() => _smtpUseImapAuth = value),
                ),
                const SizedBox(height: 8),
                _AuthFields(
                  enabled: !_smtpUseImapAuth,
                  child: Column(
                    children: [
                      _LabeledField(
                        label: 'SMTP username',
                        controller: _smtpUsernameController,
                        hintText: 'jordan',
                      ),
                      _LabeledField(
                        label: 'SMTP password',
                        controller: _smtpPasswordController,
                        hintText: '••••••••',
                        obscureText: true,
                      ),
                    ],
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.redAccent,
                        ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _connect,
                    child: _isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Connect'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            decoration: InputDecoration(hintText: hintText),
          ),
        ],
      ),
    );
  }
}

String? _autoDetectSmtpHost(String imapHost) {
  if (imapHost.isEmpty) {
    return null;
  }
  if (imapHost.startsWith('imap.')) {
    return imapHost.replaceFirst('imap.', 'smtp.');
  }
  if (imapHost.startsWith('mail.')) {
    return imapHost.replaceFirst('mail.', 'smtp.');
  }
  return 'smtp.$imapHost';
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.accent,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final Color accent;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title)),
        AccentSwitch(
          accent: accent,
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _AuthFields extends StatelessWidget {
  const _AuthFields({
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (enabled) {
      return child;
    }
    return Opacity(
      opacity: 0.45,
      child: IgnorePointer(
        ignoring: true,
        child: child,
      ),
    );
  }
}
