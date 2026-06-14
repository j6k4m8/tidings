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
        SizedBox(height: context.space(16)),
        SettingRow(
          title: 'Confirm before deleting',
          subtitle: 'Ask before moving a thread to Trash (Shift+3).',
          trailing: AccentSwitch(
            accent: accent,
            value: settings.promptBeforeDeleting,
            onChanged: settings.setPromptBeforeDeleting,
          ),
        ),
        SizedBox(height: context.space(16)),
        SettingRow(
          title: 'Undo window',
          subtitle: 'Time to undo an archive or move before it is applied.',
          trailing: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: settings.undoWindowSeconds,
              onChanged: (value) {
                if (value != null) settings.setUndoWindowSeconds(value);
              },
              items:
                  ({3, 5, 10, 15, 30, settings.undoWindowSeconds}.toList()
                        ..sort())
                      .map(
                        (n) => DropdownMenuItem(value: n, child: Text('${n}s')),
                      )
                      .toList(),
            ),
          ),
        ),
        SizedBox(height: context.space(16)),
        SettingRow(
          title: 'After archive or delete',
          subtitle: 'What the reading panel does once the thread is gone.',
          trailing: SegmentedButton<ThreadActionFollowUp>(
            style: segmentedStyle,
            segments: ThreadActionFollowUp.values
                .map(
                  (value) =>
                      ButtonSegment(value: value, label: Text(value.label)),
                )
                .toList(),
            selected: {settings.threadActionFollowUp},
            onSelectionChanged: (selected) =>
                settings.setThreadActionFollowUp(selected.first),
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
        SizedBox(height: context.space(24)),
        SettingsSubheader(title: 'SWIPE ACTIONS'),
        SizedBox(height: context.space(12)),
        SettingRow(
          title: 'Swipe actions',
          subtitle: 'Swipe a thread on touchscreens to act on it.',
          trailing: AccentSwitch(
            accent: accent,
            value: settings.swipeActionsEnabled,
            onChanged: settings.setSwipeActionsEnabled,
          ),
        ),
        if (settings.swipeActionsEnabled) ...[
          SizedBox(height: context.space(16)),
          SettingRow(
            title: 'Swipe right',
            subtitle: 'Action when a thread is swiped to the right.',
            trailing: _SwipeActionSelector(
              value: settings.swipeRightAction,
              onChanged: settings.setSwipeRightAction,
            ),
          ),
          SizedBox(height: context.space(16)),
          SettingRow(
            title: 'Swipe left',
            subtitle: 'Action when a thread is swiped to the left.',
            trailing: _SwipeActionSelector(
              value: settings.swipeLeftAction,
              onChanged: settings.setSwipeLeftAction,
            ),
          ),
        ],
      ],
    );
  }
}

class _SwipeActionSelector extends StatelessWidget {
  const _SwipeActionSelector({required this.value, required this.onChanged});

  final SwipeAction value;
  final ValueChanged<SwipeAction> onChanged;

  @override
  Widget build(BuildContext context) {
    // A dropdown (rather than a segmented button) keeps all four actions
    // readable without overflowing narrow phone widths.
    return DropdownButtonHideUnderline(
      child: DropdownButton<SwipeAction>(
        value: value,
        onChanged: (selected) {
          if (selected != null) onChanged(selected);
        },
        items: SwipeAction.values
            .map(
              (action) => DropdownMenuItem(
                value: action,
                child: Text(action.label),
              ),
            )
            .toList(),
      ),
    );
  }
}
