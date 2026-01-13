import 'package:flutter/material.dart';

import '../../theme/color_tokens.dart';
import '../../state/tidings_settings.dart';

class SettingsTabBar extends StatelessWidget {
  const SettingsTabBar({
    super.key,
    required this.tabs,
  });

  final List<String> tabs;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.tidingsSettings.densityScale;
    double space(double value) => value * densityScale;
    return Container(
      padding: EdgeInsets.all(space(4).clamp(2.0, 6.0)),
      decoration: BoxDecoration(
        color: ColorTokens.cardFill(context, 0.08),
        borderRadius: BorderRadius.circular(context.radius(16)),
        border: Border.all(color: ColorTokens.border(context)),
      ),
      child: TabBar(
        isScrollable: true,
        labelPadding:
            EdgeInsets.symmetric(horizontal: space(6).clamp(4.0, 10.0)),
        labelColor: Theme.of(context).colorScheme.onSurface,
        unselectedLabelColor: ColorTokens.textSecondary(context),
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: ColorTokens.cardFill(context, 0.18),
          borderRadius: BorderRadius.circular(context.radius(12)),
        ),
        tabs: tabs.map((tab) => SettingsTabLabel(text: tab)).toList(),
      ),
    );
  }
}

class SettingsTabLabel extends StatelessWidget {
  const SettingsTabLabel({
    super.key,
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.tidingsSettings.densityScale;
    double space(double value) => value * densityScale;
    return Tab(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: space(18).clamp(12.0, 22.0),
          vertical: space(6).clamp(4.0, 10.0),
        ),
        child: Text(text),
      ),
    );
  }
}

class SettingsTab extends StatelessWidget {
  const SettingsTab({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: context.space(8)),
      child: child,
    );
  }
}
