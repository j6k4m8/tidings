import 'package:flutter/material.dart';

import '../../state/tidings_settings.dart';
import '../../theme/account_accent.dart';
import '../../theme/color_tokens.dart';
import '../../theme/glass.dart';

class GlassBottomNav extends StatelessWidget {
  const GlassBottomNav({
    super.key,
    required this.accent,
    required this.currentIndex,
    required this.onTap,
  });

  final Color accent;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = accentTokensFor(context, accent);
    final items = const [
      _NavItem(icon: Icons.inbox_rounded, label: 'Inbox'),
      _NavItem(icon: Icons.bolt_rounded, label: 'Focus'),
      _NavItem(icon: Icons.search_rounded, label: 'Search'),
      _NavItem(icon: Icons.settings_rounded, label: 'Settings'),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.gutter(16),
          0,
          context.gutter(16),
          context.space(16),
        ),
        child: GlassPanel(
          borderRadius: BorderRadius.circular(context.radius(26)),
          padding: EdgeInsets.symmetric(
            horizontal: context.space(8),
            vertical: context.space(10),
          ),
          variant: GlassVariant.nav,
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final selected = index == currentIndex;
              final textColor = selected
                  ? tokens.onSurface
                  : ColorTokens.textSecondary(context, 0.6);

              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(vertical: context.space(8)),
                    decoration: BoxDecoration(
                      color:
                          selected ? tokens.base.withValues(alpha: 0.18) : null,
                      borderRadius: BorderRadius.circular(context.radius(18)),
                      border: Border.all(
                        color: selected
                            ? tokens.base.withValues(alpha: 0.5)
                            : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.icon, color: textColor, size: 20),
                        SizedBox(height: context.space(4)),
                        Text(
                          item.label,
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(color: textColor),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}
