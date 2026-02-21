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
import '../../widgets/accent_switch.dart';
import '../../widgets/settings/settings_rows.dart';
import '../onboarding_screen.dart';

const _kStartupUnified = 'unified';

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
    final settings = context.tidingsSettings;
    final startupId = settings.startupAccountId;

    if (appState.accounts.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Accounts', style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: context.space(12)),
          Text(
            'No accounts added.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: ColorTokens.textSecondary(context),
            ),
          ),
        ],
      );
    }

    // Two-line dropdown items: name on top, email smaller below.
    Widget accountDropdownChild(String name, String email) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.bodyMedium),
            Text(
              email,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ColorTokens.textSecondary(context),
                  ),
            ),
          ],
        );

    final dropdownItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '', child: Text('Last used')),
      const DropdownMenuItem(
          value: _kStartupUnified, child: Text('Unified Inbox')),
      for (final a in appState.accounts)
        DropdownMenuItem(
          value: a.id,
          child: accountDropdownChild(a.displayName, a.email),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Accounts', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: context.space(16)),

        SettingRow(
          title: 'On startup, open',
          subtitle: 'Which account or view to show when the app launches.',
          trailing: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: startupId ?? '',
              onChanged: (value) => settings.setStartupAccountId(
                (value == null || value.isEmpty) ? null : value,
              ),
              items: dropdownItems,
            ),
          ),
        ),

        SizedBox(height: context.space(28)),

        for (final account in appState.accounts) ...[
          AccountSection(
            appState: appState,
            account: account,
            accent: accent,
            // collapse by default when there's more than one account
            defaultExpanded: appState.accounts.length == 1,
          ),
          SizedBox(height: context.space(10)),
        ],

        SizedBox(height: context.space(4)),
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
          icon: const Icon(Icons.folder_open_rounded, size: 16),
          label: const Text('Open Settings File Directory'),
        ),
      ],
    );
  }
}

// ── Per-account card ───────────────────────────────────────────────────────────

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
  late TextEditingController _nameController;
  late FocusNode _nameFocus;
  bool _nameFocused = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.defaultExpanded;
    _nameController =
        TextEditingController(text: widget.account.displayName);
    _nameFocus = FocusNode()
      ..addListener(() {
        final focused = _nameFocus.hasFocus;
        if (focused != _nameFocused) setState(() => _nameFocused = focused);
        // On blur without explicit save: revert to saved value.
        if (!focused) {
          _nameController.text = widget.account.displayName;
        }
      });
  }

  @override
  void didUpdateWidget(AccountSection old) {
    super.didUpdateWidget(old);
    if (old.account.displayName != widget.account.displayName &&
        !_nameFocused) {
      _nameController.text = widget.account.displayName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _saveName() {
    final value = _nameController.text.trim();
    if (value.isNotEmpty) {
      widget.appState.setAccountDisplayName(widget.account.id, value);
    } else {
      _nameController.text = widget.account.displayName;
    }
    _nameFocus.unfocus();
  }

  void _cancelName() {
    _nameController.text = widget.account.displayName;
    _nameFocus.unfocus();
  }

  Future<bool> _confirmDelete(EmailAccount account) async {
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
            padding: const EdgeInsets.all(20),
            variant: GlassVariant.sheet,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Delete account?',
                    style: Theme.of(context).textTheme.titleMedium),
                SizedBox(height: context.space(8)),
                Text(
                  'This removes ${account.displayName} from Tidings. '
                  'Cached mail and settings for this account are deleted.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ColorTokens.textSecondary(context),
                      ),
                ),
                SizedBox(height: context.space(20)),
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
                            color: Colors.redAccent.withValues(alpha: 0.5)),
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
    final isImap = account.providerType == EmailProviderType.imap;

    final checkMinutes = isImap
        ? (account.imapConfig?.checkMailIntervalMinutes ?? 5)
        : (account.gmailConfig?.checkMailIntervalMinutes ?? 5);
    final crossFolder = isImap
        ? (account.imapConfig?.crossFolderThreadingEnabled ?? false)
        : (account.gmailConfig?.crossFolderThreadingEnabled ?? false);

    final baseAccent = account.accentColorValue == null
        ? accentFromAccount(account.id)
        : Color(account.accentColorValue!);

    final report = _report;
    final reportColor = report == null
        ? null
        : (report.ok ? Colors.greenAccent : Colors.redAccent);

    final glassStyle = GlassTheme.resolve(
      context,
      variant: GlassVariant.panel,
      accent: baseAccent,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: glassStyle.fill,
        borderRadius: BorderRadius.circular(context.radius(16)),
        border: Border.all(color: glassStyle.border),
        boxShadow: glassStyle.shadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(context.radius(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card header — always visible ─────────────────────────────
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.space(16),
                  vertical: context.space(14),
                ),
                child: Row(
                  children: [
                    // Accent dot — larger, visually anchoring
                    Container(
                      width: 12,
                      height: 12,
                      margin: EdgeInsets.only(right: context.space(12)),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: baseAccent,
                        boxShadow: [
                          BoxShadow(
                            color: baseAccent.withValues(alpha: 0.45),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.displayName,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            account.email,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: ColorTokens.textSecondary(context),
                                    ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: ColorTokens.textSecondary(context, 0.5),
                    ),
                  ],
                ),
              ),
            ),

            // ── Expanded body ────────────────────────────────────────────
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _expanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(
                      color: ColorTokens.border(context, 0.1), height: 1),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.space(16),
                      context.space(16),
                      context.space(16),
                      context.space(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Alias / display name ────────────────────────
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Name',
                                style:
                                    Theme.of(context).textTheme.bodyLarge),
                            SizedBox(height: context.space(6)),
                            TextField(
                              controller: _nameController,
                              focusNode: _nameFocus,
                              style: Theme.of(context).textTheme.bodyMedium,
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                hintText: 'Account name',
                                // focused border matches accent, rest uses theme
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      context.radius(18)),
                                  borderSide: BorderSide(
                                    color:
                                        baseAccent.withValues(alpha: 0.55),
                                    width: 1.2,
                                  ),
                                ),
                              ),
                              onSubmitted: (_) => _saveName(),
                            ),
                            // Cancel / Save — slide in below the field on focus
                            AnimatedSize(
                              duration: const Duration(milliseconds: 160),
                              curve: Curves.easeOut,
                              child: _nameFocused
                                  ? Padding(
                                      padding: EdgeInsets.only(
                                          top: context.space(8)),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: _cancelName,
                                            style: TextButton.styleFrom(
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                            child: const Text('Cancel'),
                                          ),
                                          SizedBox(width: context.space(8)),
                                          FilledButton(
                                            onPressed: _saveName,
                                            style: FilledButton.styleFrom(
                                              backgroundColor: baseAccent,
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                            child: const Text('Save'),
                                          ),
                                        ],
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),

                        // ── Accent color ────────────────────────────────
                        SizedBox(height: context.space(16)),
                        SettingRow(
                          title: 'Accent color',
                          subtitle:
                              'Color used for this account across the app.',
                          trailing: _AccentSwatchRow(
                            currentColor: baseAccent,
                            onColorChosen: (color) =>
                                appState.setAccountAccentColor(
                                    account.id, color),
                            onShuffle: () => appState
                                .randomizeAccountAccentColor(account.id),
                          ),
                        ),

                        // ── Check interval ──────────────────────────────
                        SizedBox(height: context.space(16)),
                        SettingRow(
                          title: 'Check for new mail',
                          subtitle: 'How often to refresh in the background.',
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
                                DropdownMenuItem(
                                    value: 1, child: Text('1 min')),
                                DropdownMenuItem(
                                    value: 5, child: Text('5 min')),
                                DropdownMenuItem(
                                    value: 10, child: Text('10 min')),
                                DropdownMenuItem(
                                    value: 15, child: Text('15 min')),
                                DropdownMenuItem(
                                    value: 30, child: Text('30 min')),
                                DropdownMenuItem(
                                    value: 60, child: Text('60 min')),
                              ],
                            ),
                          ),
                        ),

                        // ── Cross-folder threading ──────────────────────
                        SizedBox(height: context.space(12)),
                        SettingRow(
                          title: 'Include other folders in threads',
                          subtitle:
                              'Show messages from folders already fetched.',
                          trailing: AccentSwitch(
                            accent: accent,
                            value: crossFolder,
                            onChanged: (value) =>
                                appState.setAccountCrossFolderThreading(
                              accountId: account.id,
                              enabled: value,
                            ),
                          ),
                        ),

                        // ── IMAP-only actions ───────────────────────────
                        if (isImap) ...[
                          SizedBox(height: context.space(16)),
                          Wrap(
                            spacing: context.space(8),
                            runSpacing: context.space(8),
                            children: [
                              OutlinedButton.icon(
                                onPressed: _isTesting
                                    ? null
                                    : () async {
                                        setState(() {
                                          _isTesting = true;
                                          _report = null;
                                        });
                                        final result = await appState
                                            .testAccountConnection(account);
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
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(
                                        Icons.wifi_tethering_rounded),
                                label: Text(
                                    _isTesting ? 'Testing…' : 'Test Connection'),
                              ),
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

                          if (report != null) ...[
                            SizedBox(height: context.space(10)),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(context.space(10)),
                              decoration: BoxDecoration(
                                color: ColorTokens.cardFill(context, 0.06),
                                borderRadius: BorderRadius.circular(
                                    context.radius(10)),
                                border: Border.all(
                                    color: ColorTokens.border(context, 0.12)),
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
                                          Clipboard.setData(ClipboardData(
                                              text: report.log));
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content:
                                                      Text('Log copied.')));
                                        },
                                        icon: const Icon(Icons.copy_rounded,
                                            size: 16),
                                        tooltip: 'Copy log',
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: context.space(4)),
                                  SelectableText(
                                    report.log.trim(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: reportColor,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures()
                                          ],
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],

                        // ── Delete ──────────────────────────────────────
                        SizedBox(height: context.space(20)),
                        Divider(
                            color: ColorTokens.border(context, 0.1),
                            height: 1),
                        SizedBox(height: context.space(14)),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final confirmed = await _confirmDelete(account);
                            if (!confirmed) return;
                            await appState.removeAccount(account.id);
                          },
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Delete account'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: BorderSide(
                                color:
                                    Colors.redAccent.withValues(alpha: 0.5)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Accent swatch quick-pick row ───────────────────────────────────────────────

class _AccentSwatchRow extends StatelessWidget {
  const _AccentSwatchRow({
    required this.currentColor,
    required this.onColorChosen,
    required this.onShuffle,
  });

  final Color currentColor;
  final ValueChanged<Color> onColorChosen;
  final VoidCallback onShuffle;

  void _openFullPicker(BuildContext context) {
    Color working = currentColor;
    final hexController = TextEditingController(text: _toHex(working));

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void applyHex(String raw) {
            final color = _fromHex(raw);
            if (color != null) setDialogState(() => working = color);
          }

          return AlertDialog(
            title: const Text('Accent color'),
            contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final preset in accentPresets)
                        Tooltip(
                          message: preset.label,
                          child: GestureDetector(
                            onTap: () => setDialogState(() {
                              working = preset.color;
                              hexController.text = _toHex(preset.color);
                            }),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: preset.color,
                                  border: Border.all(
                                    color: working.toARGB32() ==
                                            preset.color.toARGB32()
                                        ? Theme.of(ctx).colorScheme.primary
                                        : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ColorPicker(
                    pickerColor: working,
                    onColorChanged: (c) => setDialogState(() {
                      working = c;
                      hexController.text = _toHex(c);
                    }),
                    enableAlpha: false,
                    labelTypes: const [],
                    pickerAreaHeightPercent: 0.5,
                    displayThumbColor: true,
                  ),
                  const SizedBox(height: 4),
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
                                horizontal: 8, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 13),
                          maxLength: 6,
                          buildCounter: (_, {
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
                  onColorChosen(working);
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 6 quick-pick dots — evenly spread across the hue wheel
        for (final preset in accentPresets.take(6))
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Tooltip(
              message: preset.label,
              child: GestureDetector(
                onTap: () => onColorChosen(preset.color),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: preset.color,
                      border: Border.all(
                        color: currentColor.toARGB32() ==
                                preset.color.toARGB32()
                            ? ColorTokens.textPrimary(context)
                                .withValues(alpha: 0.85)
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

        // "More" — opens full picker
        Tooltip(
          message: 'More colors…',
          child: GestureDetector(
            onTap: () => _openFullPicker(context),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ColorTokens.border(context, 0.35),
                  ),
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 13,
                  color: ColorTokens.textSecondary(context, 0.6),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 2),
        IconButton(
          onPressed: onShuffle,
          icon: const Icon(Icons.shuffle_rounded, size: 16),
          tooltip: 'Random color',
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

// ── Hex helpers ────────────────────────────────────────────────────────────────

String _toHex(Color c) {
  final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
  final g = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
  final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
  return '$r$g$b'.toUpperCase();
}

Color? _fromHex(String raw) {
  var s = raw.trim().replaceAll('#', '');
  if (s.length == 3) s = '${s[0]}${s[0]}${s[1]}${s[1]}${s[2]}${s[2]}';
  if (s.length != 6) return null;
  final value = int.tryParse('FF$s', radix: 16);
  return value == null ? null : Color(value);
}
