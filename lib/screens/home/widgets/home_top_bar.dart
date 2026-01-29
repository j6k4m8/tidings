import 'package:flutter/material.dart';

import '../../../theme/color_tokens.dart';
import '../../../theme/glass.dart';
import '../../../state/tidings_settings.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.accent,
    required this.searchFocusNode,
    required this.onSettingsTap,
    required this.onAccountTap,
  });

  final Color accent;
  final FocusNode searchFocusNode;
  final VoidCallback onSettingsTap;
  final VoidCallback onAccountTap;

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
                IconButton(
                  tooltip: 'Account',
                  onPressed: onAccountTap,
                  icon: const Icon(Icons.account_circle_outlined),
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
