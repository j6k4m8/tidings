import 'package:flutter/material.dart';

import '../../../theme/color_tokens.dart';
import '../../../theme/glass.dart';
import 'refresh_button.dart';
import '../../../state/tidings_settings.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.accent,
    required this.searchFocusNode,
    required this.onSettingsTap,
    required this.onOutboxTap,
    required this.onRefreshTap,
    required this.isRefreshing,
    required this.outboxCount,
    required this.outboxSelected,
  });

  final Color accent;
  final FocusNode searchFocusNode;
  final VoidCallback onSettingsTap;
  final VoidCallback onOutboxTap;
  final VoidCallback onRefreshTap;
  final bool isRefreshing;
  final int outboxCount;
  final bool outboxSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.of(context).padding.top;
    final borderRadius = BorderRadius.circular(context.radius(18));
    final highlight = GlassTheme.resolve(
      context,
      variant: GlassVariant.nav,
      accent: accent,
      selected: true,
    ).highlight;
    final searchFill = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.white.withValues(alpha: 0.7);
    final barBase = isDark ? const Color(0xFF0F141D) : const Color(0xFFF1F4F8);
    final barColor = Color.alphaBlend(
      accent.withValues(alpha: isDark ? 0.35 : 0.22),
      barBase,
    );

    return Container(
      decoration: BoxDecoration(
        color: barColor,
        border: Border.all(color: ColorTokens.border(context, 0.12)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: highlight),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.space(14),
              topInset + context.space(6),
              context.space(14),
              context.space(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: TextField(
                        focusNode: searchFocusNode,
                        decoration: InputDecoration(
                          hintText: 'Search',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 18,
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: searchFill,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: context.space(10),
                            horizontal: context.space(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: borderRadius,
                            borderSide: BorderSide(
                              color: ColorTokens.border(context, 0.12),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: borderRadius,
                            borderSide: BorderSide(
                              color: accent.withValues(alpha: 0.45),
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: context.space(12)),
                _OutboxButton(
                  count: outboxCount,
                  accent: accent,
                  selected: outboxSelected,
                  onTap: onOutboxTap,
                ),
                RefreshIconButton(
                  isRefreshing: isRefreshing,
                  onPressed: onRefreshTap,
                ),
                IconButton(
                  tooltip: 'Settings',
                  onPressed: onSettingsTap,
                  icon: const Icon(Icons.settings_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OutboxButton extends StatelessWidget {
  const _OutboxButton({
    required this.count,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final int count;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : count.toString();
    final badgeVisible = count > 0;
    final iconColor = selected ? accent.withValues(alpha: 0.9) : null;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: badgeVisible ? 'Outbox ($label)' : 'Outbox',
          onPressed: onTap,
          icon: Icon(Icons.outbox_rounded, color: iconColor),
        ),
        if (badgeVisible)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
      ],
    );
  }
}
