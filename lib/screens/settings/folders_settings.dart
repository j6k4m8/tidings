import 'package:flutter/material.dart';

import '../../state/tidings_settings.dart';
import '../../widgets/accent_switch.dart';
import '../../widgets/settings/settings_rows.dart';

class FoldersSettings extends StatelessWidget {
  const FoldersSettings({super.key, required this.accent});

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
              'Display a folder badge on messages that live in a different '
              'folder from the current view.',
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
