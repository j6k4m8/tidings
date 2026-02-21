import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../state/tidings_settings.dart';
import '../../theme/color_tokens.dart';
import '../../theme/glass.dart';
import '../../widgets/settings/settings_tabs.dart';
import 'accounts_settings.dart';
import 'appearance_settings.dart';
import 'folders_settings.dart';
import 'keyboard_settings.dart';
import 'layout_settings.dart';
import 'threads_settings.dart';

export 'accounts_settings.dart' show AccountSection;

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
        if (states.contains(WidgetState.selected)) return accent;
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
                    child: AppearanceSettings(
                      accent: accent,
                      segmentedStyle: segmentedStyle,
                    ),
                  ),
                  SettingsTab(
                    child: LayoutSettings(segmentedStyle: segmentedStyle),
                  ),
                  SettingsTab(
                    child: ThreadsSettings(segmentedStyle: segmentedStyle),
                  ),
                  SettingsTab(child: FoldersSettings(accent: accent)),
                  SettingsTab(
                    child: AccountsSettings(
                      appState: appState,
                      accent: accent,
                    ),
                  ),
                  const SettingsTab(child: KeyboardSettings()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
