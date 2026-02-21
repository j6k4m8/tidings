import 'package:flutter/material.dart';

import '../../state/keyboard_shortcut.dart';
import '../../state/shortcut_definitions.dart';
import '../../state/tidings_settings.dart';
import '../../theme/color_tokens.dart';
import '../../widgets/settings/settings_rows.dart';
import '../../widgets/settings/shortcut_recorder.dart';

class KeyboardSettings extends StatelessWidget {
  const KeyboardSettings({super.key});

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
    if (label == null) return child;
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
