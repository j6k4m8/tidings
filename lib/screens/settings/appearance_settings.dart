import 'package:flutter/material.dart';

import '../../state/tidings_settings.dart';
import '../../theme/theme_palette.dart';
import '../../widgets/accent_switch.dart';
import '../../widgets/settings/settings_rows.dart';

class AppearanceSettings extends StatelessWidget {
  const AppearanceSettings({
    super.key,
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
        SizedBox(height: context.space(24)),
        SettingsSubheader(title: 'DATE & TIME'),
        SizedBox(height: context.space(12)),
        SettingRow(
          title: 'Date order',
          subtitle: 'How month, day, and year appear in timestamps.',
          trailing: SegmentedButton<DateOrder>(
            style: segmentedStyle,
            segments: const [
              ButtonSegment(value: DateOrder.mdy, label: Text('M D Y')),
              ButtonSegment(value: DateOrder.dmy, label: Text('D M Y')),
              ButtonSegment(value: DateOrder.ymd, label: Text('Y M D')),
            ],
            selected: {settings.dateOrder},
            onSelectionChanged: (selection) {
              settings.setDateOrder(selection.first);
            },
          ),
        ),
        SizedBox(height: context.space(16)),
        SettingRow(
          title: '24-hour clock',
          subtitle: 'Show times as 13:45 instead of 1:45 PM.',
          trailing: AccentSwitch(
            accent: accent,
            value: settings.use24HourTime,
            onChanged: settings.setUse24HourTime,
          ),
        ),
      ],
    );
  }
}
