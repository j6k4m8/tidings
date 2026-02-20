import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/account_models.dart';
import '../../state/app_state.dart';
import '../../state/keyboard_shortcut.dart';
import '../../state/shortcut_definitions.dart';
import '../../state/tidings_settings.dart';
import '../../theme/account_accent.dart';
import '../../theme/color_tokens.dart';
import '../../theme/glass.dart';
import '../../theme/theme_palette.dart';
import '../../widgets/accent/accent_presets.dart';
import '../../widgets/accent/accent_swatch.dart';
import '../../widgets/accent_switch.dart';
import '../../widgets/settings/corner_radius_option.dart';
import '../../widgets/settings/settings_rows.dart';
import '../../widgets/settings/settings_tabs.dart';
import '../../widgets/settings/shortcut_recorder.dart';
import '../onboarding_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.accent,
    required this.appState,
    this.onClose,
  });

  final Color accent;
  final AppState appState;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(context.gutter(16)),
      child: SettingsPanel(
        accent: accent,
        appState: appState,
        onClose: onClose,
      ),
    );
  }
}

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({
    super.key,
    required this.accent,
    required this.appState,
    this.onClose,
  });

  final Color accent;
  final AppState appState;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final segmentedStyle = ButtonStyle(
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: context.space(10),
          vertical: context.space(6),
        ),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.radius(12)),
        ),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return accent.withValues(alpha: 0.18);
        }
        return ColorTokens.cardFill(context, 0.08);
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return accent;
        }
        return ColorTokens.textSecondary(context, 0.7);
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return BorderSide(color: accent.withValues(alpha: 0.5));
        }
        return BorderSide(color: ColorTokens.border(context, 0.1));
      }),
    );

    return GlassPanel(
      borderRadius: BorderRadius.circular(context.radius(28)),
      padding: EdgeInsets.all(context.space(14)),
      variant: GlassVariant.sheet,
      child: DefaultTabController(
        length: 6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Settings',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close settings',
                  ),
              ],
            ),
            SizedBox(height: context.space(12)),
            const SettingsTabBar(
              tabs: [
                'Appearance',
                'Layout',
                'Threads',
                'Folders',
                'Accounts',
                'Keyboard',
              ],
            ),
            SizedBox(height: context.space(12)),
            Expanded(
              child: TabBarView(
                children: [
                  SettingsTab(
                    child: _AppearanceSettings(
                      accent: accent,
                      segmentedStyle: segmentedStyle,
                    ),
                  ),
                  SettingsTab(
                    child: _LayoutSettings(segmentedStyle: segmentedStyle),
                  ),
                  SettingsTab(
                    child: _ThreadsSettings(segmentedStyle: segmentedStyle),
                  ),
                  SettingsTab(child: _FoldersSettings(accent: accent)),
                  SettingsTab(
                    child: _AccountsSettings(
                      appState: appState,
                      accent: accent,
                    ),
                  ),
                  const SettingsTab(child: _KeyboardSettings()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppearanceSettings extends StatelessWidget {
  const _AppearanceSettings({
    required this.accent,
    required this.segmentedStyle,
  });

  final Color accent;
  final ButtonStyle segmentedStyle;

  @override
  Widget build(BuildContext context) {
    final settings = context.tidingsSettings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: context.space(12)),
        SettingRow(
          title: 'Theme',
          subtitle: 'Follow system appearance or set manually.',
          trailing: SegmentedButton<ThemeMode>(
            style: segmentedStyle,
            segments: const [
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (selection) {
              settings.setThemeMode(selection.first);
            },
          ),
        ),
        SizedBox(height: context.space(16)),
        SettingRow(
          title: 'Theme palette',
          subtitle: 'Neutral or account-accent gradients.',
          trailing: SegmentedButton<ThemePaletteSource>(
            style: segmentedStyle,
            segments: ThemePaletteSource.values
                .map(
                  (source) =>
                      ButtonSegment(value: source, label: Text(source.label)),
                )
                .toList(),
            selected: {settings.paletteSource},
            onSelectionChanged: (selection) {
              settings.setPaletteSource(selection.first);
            },
          ),
        ),
      ],
    );
  }
}

class _LayoutSettings extends StatelessWidget {
  const _LayoutSettings({required this.segmentedStyle});

  final ButtonStyle segmentedStyle;

  @override
  Widget build(BuildContext context) {
    final settings = context.tidingsSettings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Layout', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: context.space(12)),
        SettingRow(
          title: 'Layout density',
          subtitle: 'Compactness and margins in one setting.',
          trailing: SegmentedButton<LayoutDensity>(
            style: segmentedStyle,
            segments: LayoutDensity.values
                .map(
                  (density) =>
                      ButtonSegment(value: density, label: Text(density.label)),
                )
                .toList(),
            selected: {settings.layoutDensity},
            onSelectionChanged: (selection) {
              settings.setLayoutDensity(selection.first);
            },
          ),
        ),
        SizedBox(height: context.space(16)),
        SettingRow(
          title: 'Corner radius',
          subtitle: 'Dial in how rounded the UI feels.',
          trailing: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 420;
              final children = CornerRadiusStyle.values
                  .map(
                    (style) => SizedBox(
                      width: isNarrow ? 160 : 120,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.space(4),
                          vertical: context.space(4),
                        ),
                        child: CornerRadiusOption(
                          label: style.label,
                          radius: context.space(18) * style.scale,
                          selected: settings.cornerRadiusStyle == style,
                          onTap: () => settings.setCornerRadiusStyle(style),
                        ),
                      ),
                    ),
                  )
                  .toList();
              return Wrap(
                spacing: context.space(4),
                runSpacing: context.space(4),
                children: children,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ThreadsSettings extends StatelessWidget {
  const _ThreadsSettings({required this.segmentedStyle});

  final ButtonStyle segmentedStyle;

  @override
  Widget build(BuildContext context) {
    final settings = context.tidingsSettings;
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Threads', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: context.space(12)),
        SettingRow(
          title: 'Auto-expand unread',
          subtitle: 'Open unread threads to show the latest message.',
          trailing: AccentSwitch(
            accent: accent,
            value: settings.autoExpandUnread,
            onChanged: settings.setAutoExpandUnread,
          ),
        ),
        SizedBox(height: context.space(16)),
        SettingRow(
          title: 'Auto-expand latest',
          subtitle: 'Keep the newest thread expanded in the list.',
          trailing: AccentSwitch(
            accent: accent,
            value: settings.autoExpandLatest,
            onChanged: settings.setAutoExpandLatest,
          ),
        ),
        SizedBox(height: context.space(16)),
        SettingRow(
          title: 'Hide subject lines',
          subtitle: 'Show only the message body in thread view.',
          trailing: AccentSwitch(
            accent: accent,
            value: settings.hideThreadSubjects,
            onChanged: settings.setHideThreadSubjects,
          ),
        ),
        SizedBox(height: context.space(16)),
        SettingRow(
          title: 'Hide yourself in thread list',
          subtitle: 'Remove your address from sender rows.',
          trailing: AccentSwitch(
            accent: accent,
            value: settings.hideSelfInThreadList,
            onChanged: settings.setHideSelfInThreadList,
          ),
        ),
        SizedBox(height: context.space(16)),
        SettingRow(
          title: 'Tint thread list by account',
          subtitle: 'Use a subtle account accent behind each thread.',
          trailing: AccentSwitch(
            accent: accent,
            value: settings.tintThreadListByAccountAccent,
            onChanged: settings.setTintThreadListByAccountAccent,
          ),
        ),
        SizedBox(height: context.space(16)),
        SettingRow(
          title: 'Show account label in list',
          subtitle: 'Display the account on each unified thread.',
          trailing: AccentSwitch(
            accent: accent,
            value: settings.showThreadAccountPill,
            onChanged: settings.setShowThreadAccountPill,
          ),
        ),
        SizedBox(height: context.space(24)),
        SettingsSubheader(title: 'MESSAGE PREVIEW'),
        SizedBox(height: context.space(12)),
        SettingRow(
          title: 'Collapse mode',
          subtitle: 'How to shorten long messages in collapsed view.',
          trailing: SegmentedButton<MessageCollapseMode>(
            style: segmentedStyle,
            segments: MessageCollapseMode.values
                .map(
                  (mode) => ButtonSegment(value: mode, label: Text(mode.label)),
                )
                .toList(),
            selected: {settings.messageCollapseMode},
            onSelectionChanged: (selected) =>
                settings.setMessageCollapseMode(selected.first),
          ),
        ),
        if (settings.messageCollapseMode == MessageCollapseMode.maxLines) ...[
          SizedBox(height: context.space(16)),
          SettingRow(
            title: 'Max lines',
            subtitle: 'Number of lines to show before truncating.',
            trailing: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: settings.collapsedMaxLines,
                onChanged: (value) {
                  if (value != null) {
                    settings.setCollapsedMaxLines(value);
                  }
                },
                items: [4, 6, 8, 10, 12, 15, 20]
                    .map(
                      (n) =>
                          DropdownMenuItem(value: n, child: Text('$n lines')),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FoldersSettings extends StatelessWidget {
  const _FoldersSettings({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final settings = context.tidingsSettings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Folders', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: context.space(12)),
        SettingRow(
          title: 'Show labels',
          subtitle: 'Include the Labels section in the sidebar.',
          trailing: AccentSwitch(
            accent: accent,
            value: settings.showFolderLabels,
            onChanged: settings.setShowFolderLabels,
          ),
        ),
        SizedBox(height: context.space(16)),
        SettingRow(
          title: 'Unread counts',
          subtitle: 'Show unread badge counts next to folders.',
          trailing: AccentSwitch(
            accent: accent,
            value: settings.showFolderUnreadCounts,
            onChanged: settings.setShowFolderUnreadCounts,
          ),
        ),
        SizedBox(height: context.space(16)),
        SettingRow(
          title: 'Move entire thread by default',
          subtitle:
              'Pre-select "Move entire thread" in the Move to Folder dialog.',
          trailing: AccentSwitch(
            accent: accent,
            value: settings.moveEntireThreadByDefault,
            onChanged: settings.setMoveEntireThreadByDefault,
          ),
        ),
        SizedBox(height: context.space(16)),
        SettingRow(
          title: 'Show message folder source',
          subtitle:
              'Display a folder badge on messages that live in a different folder from the current view.',
          trailing: AccentSwitch(
            accent: accent,
            value: settings.showMessageFolderSource,
            onChanged: settings.setShowMessageFolderSource,
          ),
        ),
      ],
    );
  }
}

class _AccountsSettings extends StatelessWidget {
  const _AccountsSettings({required this.appState, required this.accent});

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
            if (!context.mounted) {
              return;
            }
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
          _AccountSection(
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

class _KeyboardSettings extends StatelessWidget {
  const _KeyboardSettings();

  @override
  Widget build(BuildContext context) {
    final settings = context.tidingsSettings;
    final navigation = <ShortcutAction>[
      ShortcutAction.navigateNext,
      ShortcutAction.navigatePrev,
      ShortcutAction.openThread,
      ShortcutAction.toggleSidebar,
      ShortcutAction.goTo,
      ShortcutAction.goToAccount,
      ShortcutAction.focusSearch,
      ShortcutAction.openSettings,
    ];
    final compose = <ShortcutAction>[
      ShortcutAction.compose,
      ShortcutAction.reply,
      ShortcutAction.replyAll,
      ShortcutAction.forward,
      ShortcutAction.sendMessage,
    ];
    final mailbox = <ShortcutAction>[
      ShortcutAction.archive,
      ShortcutAction.commandPalette,
      ShortcutAction.showShortcuts,
    ];

    Widget buildSection(String title, List<ShortcutAction> actions) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSubheader(title: title),
          SizedBox(height: context.space(10)),
          for (final action in actions) ...[
            _ShortcutRow(
              definition: definitionFor(action),
              primary: settings.shortcutFor(action),
              secondary: settings.secondaryShortcutFor(action),
              onPrimaryChanged: (value) => settings.setShortcut(action, value),
              onSecondaryChanged: (value) =>
                  settings.setShortcut(action, value, secondary: true),
            ),
            SizedBox(height: context.space(14)),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Keyboard', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: context.space(12)),
        Text(
          'Edit keyboard shortcuts for power navigation.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: ColorTokens.textSecondary(context),
          ),
        ),
        SizedBox(height: context.space(16)),
        buildSection('Navigation', navigation),
        SizedBox(height: context.space(10)),
        buildSection('Compose', compose),
        SizedBox(height: context.space(10)),
        buildSection('Mailbox', mailbox),
      ],
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.definition,
    required this.primary,
    required this.secondary,
    required this.onPrimaryChanged,
    required this.onSecondaryChanged,
  });

  final ShortcutDefinition definition;
  final KeyboardShortcut primary;
  final KeyboardShortcut? secondary;
  final ValueChanged<KeyboardShortcut> onPrimaryChanged;
  final ValueChanged<KeyboardShortcut> onSecondaryChanged;

  @override
  Widget build(BuildContext context) {
    final secondaryShortcut = secondary ?? definition.secondaryDefault;
    return SettingRow(
      title: definition.label,
      subtitle: definition.description,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _ShortcutSlot(
            label: definition.secondaryDefault != null ? 'Primary' : null,
            child: ShortcutRecorder(
              shortcut: primary,
              onChanged: onPrimaryChanged,
            ),
          ),
          if (secondaryShortcut != null) ...[
            SizedBox(height: context.space(8)),
            _ShortcutSlot(
              label: 'Alternate',
              child: ShortcutRecorder(
                shortcut: secondaryShortcut,
                onChanged: onSecondaryChanged,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShortcutSlot extends StatelessWidget {
  const _ShortcutSlot({required this.child, this.label});

  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return child;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label!,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: ColorTokens.textSecondary(context),
          ),
        ),
        SizedBox(height: context.space(4)),
        child,
      ],
    );
  }
}

class _AccountSection extends StatefulWidget {
  const _AccountSection({
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
  State<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<_AccountSection> {
  bool _isTesting = false;
  ConnectionTestReport? _report;
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.defaultExpanded;
  }

  Future<bool> _confirmDeleteAccount(
    BuildContext context,
    EmailAccount account,
  ) async {
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
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  ],
                ),
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
                          if (value == null) {
                            return;
                          }
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
                                if (!mounted) {
                                  return;
                                }
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
                                  strokeWidth: 2,
                                ),
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
                if (report != null) ...[
                  SizedBox(height: context.space(12)),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(context.space(12)),
                    decoration: BoxDecoration(
                      color: ColorTokens.cardFill(context, 0.06),
                      borderRadius: BorderRadius.circular(context.radius(12)),
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
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: reportColor),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: report.log),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Log copied.')),
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
                          style: Theme.of(context).textTheme.bodySmall
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
                SizedBox(height: context.space(16)),
                Divider(color: ColorTokens.border(context, 0.12)),
                SizedBox(height: context.space(12)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await _confirmDeleteAccount(
                        context,
                        account,
                      );
                      if (!confirmed) {
                        return;
                      }
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
