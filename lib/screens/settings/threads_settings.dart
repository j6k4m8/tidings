import 'package:flutter/material.dart';

import '../../state/tidings_settings.dart';
import '../../widgets/accent_switch.dart';
import '../../widgets/settings/settings_rows.dart';

class ThreadsSettings extends StatelessWidget {
  const ThreadsSettings({super.key, required this.segmentedStyle});

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
                  if (value != null) settings.setCollapsedMaxLines(value);
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
