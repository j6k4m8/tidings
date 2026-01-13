import 'package:flutter/material.dart';

import '../models/account_models.dart';
import '../state/app_state.dart';
import '../theme/color_tokens.dart';
import '../theme/glass.dart';
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

class _AccountSetupSheetState extends State<_AccountSetupSheet> {
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _serverController = TextEditingController();
  final _portController = TextEditingController(text: '993');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _useTls = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _serverController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final displayName = _displayNameController.text.trim();
    final email = _emailController.text.trim();
    final server = _serverController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (displayName.isEmpty ||
        email.isEmpty ||
        server.isEmpty ||
        username.isEmpty ||
        password.isEmpty) {
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
    final config = ImapAccountConfig(
      server: server,
      port: port,
      username: username,
      password: password,
      useTls: _useTls,
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
                SwitchListTile.adaptive(
                  value: _useTls,
                  onChanged: (value) => setState(() => _useTls = value),
                  title: const Text('Use TLS'),
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
