import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../models/account_models.dart';
import '../../state/app_state.dart';
import '../../state/tidings_settings.dart';
import '../../theme/account_accent.dart';
import '../../theme/color_tokens.dart';
import '../../theme/glass.dart';
import '../../widgets/accent/accent_presets.dart';
import '../../widgets/accent/accent_swatch.dart';
import '../../widgets/accent_switch.dart';
import '../../widgets/settings/settings_rows.dart';
import '../onboarding_screen.dart';

class AccountsSettings extends StatelessWidget {
  const AccountsSettings({
    super.key,
    required this.appState,
    required this.accent,
  });

  final AppState appState;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (appState.accounts.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Accounts', style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: context.space(12)),
          Text(
            'No account selected.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: ColorTokens.textSecondary(context),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Accounts', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: context.space(8)),
        Text(
          'Manage per-account settings and verify connections.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: ColorTokens.textSecondary(context),
          ),
        ),
        SizedBox(height: context.space(10)),
        OutlinedButton.icon(
          onPressed: () async {
            final error = await appState.openConfigDirectory();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  error == null
                      ? 'Opened settings directory.'
                      : 'Unable to open settings directory: $error',
                ),
              ),
            );
          },
          icon: const Icon(Icons.folder_open_rounded),
          label: const Text('Open Settings File Directory'),
        ),
        SizedBox(height: context.space(12)),
        for (final account in appState.accounts) ...[
          AccountSection(
            appState: appState,
            account: account,
            accent: accent,
            defaultExpanded: appState.accounts.length < 3,
          ),
          SizedBox(height: context.space(16)),
        ],
      ],
    );
  }
}

// ── Per-account expandable section ────────────────────────────────────────────

class AccountSection extends StatefulWidget {
  const AccountSection({
    super.key,
    required this.appState,
    required this.account,
    required this.accent,
    required this.defaultExpanded,
  });

  final AppState appState;
  final EmailAccount account;
  final Color accent;
  final bool defaultExpanded;

  @override
  State<AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<AccountSection> {
  bool _isTesting = false;
  ConnectionTestReport? _report;
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.defaultExpanded;
  }

  Future<bool> _confirmDeleteAccount(EmailAccount account) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: GlassPanel(
            borderRadius: BorderRadius.circular(20),
            padding: const EdgeInsets.all(16),
            variant: GlassVariant.sheet,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delete account?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: context.space(8)),
                Text(
                  'This removes ${account.displayName} from Tidings. '
                  'Cached mail and settings for this account are deleted.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ColorTokens.textSecondary(context),
                  ),
                ),
                SizedBox(height: context.space(16)),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.delete_outline_rounded),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: BorderSide(
                          color: Colors.redAccent.withValues(alpha: 0.5),
                        ),
                      ),
                      label: const Text('Delete account'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final appState = widget.appState;
    final accent = widget.accent;
    final checkMinutes = account.imapConfig?.checkMailIntervalMinutes ?? 5;
    final crossFolderEnabled =
        account.imapConfig?.crossFolderThreadingEnabled ?? false;
    final baseAccent = account.accentColorValue == null
        ? accentFromAccount(account.id)
        : Color(account.accentColorValue!);
    final report = _report;
    final reportColor = report == null
        ? null
        : (report.ok ? Colors.greenAccent : Colors.redAccent);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.space(14)),
      decoration: BoxDecoration(
        color: ColorTokens.cardFill(context, 0.04),
        borderRadius: BorderRadius.circular(context.radius(18)),
        border: Border.all(color: ColorTokens.border(context, 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row (tap to expand) ──────────────────────────────────
          InkWell(
            borderRadius: BorderRadius.circular(context.radius(12)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: context.space(6),
                horizontal: context.space(4),
              ),
              child: Row(
                children: [
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_right_rounded,
                  ),
                  SizedBox(width: context.space(6)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        account.email,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ColorTokens.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded body ────────────────────────────────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Accent picker
                SizedBox(height: context.space(8)),
                Row(
                  children: [
                    Text(
                      'Accent',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () =>
                          appState.randomizeAccountAccentColor(account.id),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Shuffle'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.space(8),
                          vertical: context.space(4),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.space(8)),
                Wrap(
                  spacing: context.space(12),
                  runSpacing: context.space(8),
                  children: [
                    for (final preset in accentPresets)
                      AccentSwatch(
                        label: preset.label,
                        color: resolveAccent(
                          preset.color,
                          Theme.of(context).brightness,
                        ),
                        selected:
                            preset.color.toARGB32() == baseAccent.toARGB32(),
                        onTap: () => appState.setAccountAccentColor(
                          account.id,
                          preset.color,
                        ),
                      ),
                    CustomAccentSwatch(
                      currentColor: baseAccent,
                      isCustom: accentPresets.every(
                        (p) => p.color.toARGB32() != baseAccent.toARGB32(),
                      ),
                      onColorChosen: (color) =>
                          appState.setAccountAccentColor(account.id, color),
                    ),
                  ],
                ),

                // Connection settings
                SizedBox(height: context.space(16)),
                Divider(color: ColorTokens.border(context, 0.12)),
                SizedBox(height: context.space(12)),
                Text(
                  'Connection',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (account.providerType == EmailProviderType.imap) ...[
                  SizedBox(height: context.space(8)),
                  SettingRow(
                    title: 'Check for new mail',
                    subtitle: 'Background refresh interval for Inbox.',
                    trailing: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: checkMinutes,
                        onChanged: (value) {
                          if (value == null) return;
                          appState.setAccountCheckInterval(
                            accountId: account.id,
                            minutes: value,
                          );
                        },
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('1 min')),
                          DropdownMenuItem(value: 5, child: Text('5 min')),
                          DropdownMenuItem(value: 10, child: Text('10 min')),
                          DropdownMenuItem(value: 15, child: Text('15 min')),
                          DropdownMenuItem(value: 30, child: Text('30 min')),
                          DropdownMenuItem(value: 60, child: Text('60 min')),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: context.space(16)),
                  SettingRow(
                    title: 'Include other folders in threads',
                    subtitle: 'Show messages from folders already fetched.',
                    trailing: AccentSwitch(
                      accent: accent,
                      value: crossFolderEnabled,
                      onChanged: (value) =>
                          appState.setAccountCrossFolderThreading(
                        accountId: account.id,
                        enabled: value,
                      ),
                    ),
                  ),
                ],
                SizedBox(height: context.space(12)),
                Wrap(
                  spacing: context.space(8),
                  runSpacing: context.space(8),
                  children: [
                    if (account.providerType == EmailProviderType.imap)
                      OutlinedButton.icon(
                        onPressed: _isTesting
                            ? null
                            : () async {
                                setState(() {
                                  _isTesting = true;
                                  _report = null;
                                });
                                final result =
                                    await appState.testAccountConnection(
                                  account,
                                );
                                if (!mounted) return;
                                setState(() {
                                  _isTesting = false;
                                  _report = result;
                                });
                              },
                        icon: _isTesting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi_tethering_rounded),
                        label: Text(
                          _isTesting ? 'Testing...' : 'Test Connection',
                        ),
                      ),
                    if (account.providerType == EmailProviderType.imap)
                      OutlinedButton.icon(
                        onPressed: () => showAccountEditSheet(
                          context,
                          appState: appState,
                          account: account,
                          accent: accent,
                        ),
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Edit IMAP/SMTP'),
                      ),
                  ],
                ),

                // Connection test result
                if (report != null) ...[
                  SizedBox(height: context.space(12)),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(context.space(12)),
                    decoration: BoxDecoration(
                      color: ColorTokens.cardFill(context, 0.06),
                      borderRadius:
                          BorderRadius.circular(context.radius(12)),
                      border: Border.all(
                        color: ColorTokens.border(context, 0.12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              report.ok
                                  ? 'Connection OK'
                                  : 'Connection failed',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(color: reportColor),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: report.log),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Log copied.')),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              tooltip: 'Copy log',
                            ),
                          ],
                        ),
                        SizedBox(height: context.space(6)),
                        SelectableText(
                          report.log.trim(),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: reportColor,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Delete account
                SizedBox(height: context.space(16)),
                Divider(color: ColorTokens.border(context, 0.12)),
                SizedBox(height: context.space(12)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed =
                          await _confirmDeleteAccount(account);
                      if (!confirmed) return;
                      await appState.removeAccount(account.id);
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete account'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: BorderSide(
                        color: Colors.redAccent.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── Custom accent colour picker ────────────────────────────────────────────────

class CustomAccentSwatch extends StatefulWidget {
  const CustomAccentSwatch({
    super.key,
    required this.currentColor,
    required this.isCustom,
    required this.onColorChosen,
  });

  final Color currentColor;
  final bool isCustom;
  final ValueChanged<Color> onColorChosen;

  @override
  State<CustomAccentSwatch> createState() => _CustomAccentSwatchState();
}

class _CustomAccentSwatchState extends State<CustomAccentSwatch> {
  void _open() {
    Color working =
        widget.isCustom ? widget.currentColor : const Color(0xFF4A9FFF);
    final hexController = TextEditingController(text: _toHex(working));

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            void applyHex(String raw) {
              final color = _fromHex(raw);
              if (color != null) setDialogState(() => working = color);
            }

            return AlertDialog(
              title: const Text('Custom colour'),
              contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ColorPicker(
                      pickerColor: working,
                      onColorChanged: (c) {
                        setDialogState(() {
                          working = c;
                          hexController.text = _toHex(c);
                        });
                      },
                      enableAlpha: false,
                      labelTypes: const [],
                      pickerAreaHeightPercent: 0.6,
                      displayThumbColor: true,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('#', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TextField(
                            controller: hexController,
                            decoration: const InputDecoration(
                              hintText: 'RRGGBB',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(),
                            ),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                            maxLength: 6,
                            buildCounter: (
                              _, {
                              required currentLength,
                              required isFocused,
                              maxLength,
                            }) =>
                                null,
                            onSubmitted: applyHex,
                            onChanged: applyHex,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: working,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(ctx)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    widget.onColorChosen(working);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final densityScale = context.tidingsSettings.densityScale;
    double space(double v) => v * densityScale;
    final size = space(24).clamp(18.0, 30.0);

    final Widget circle = widget.isCustom
        ? Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.currentColor,
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
          )
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [
                  Color(0xFFFF0000),
                  Color(0xFFFFFF00),
                  Color(0xFF00FF00),
                  Color(0xFF00FFFF),
                  Color(0xFF0000FF),
                  Color(0xFFFF00FF),
                  Color(0xFFFF0000),
                ],
              ),
              border: Border.all(color: Colors.transparent, width: 2),
            ),
          );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _open,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            circle,
            SizedBox(width: space(8)),
            Text('Custom', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

// ── Hex helpers ───────────────────────────────────────────────────────────────

String _toHex(Color c) {
  final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
  final g = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
  final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
  return '$r$g$b'.toUpperCase();
}

Color? _fromHex(String raw) {
  var s = raw.trim().replaceAll('#', '');
  if (s.length == 3) {
    s = '${s[0]}${s[0]}${s[1]}${s[1]}${s[2]}${s[2]}';
  }
  if (s.length != 6) return null;
  final value = int.tryParse('FF$s', radix: 16);
  return value == null ? null : Color(value);
}
