import 'package:flutter/material.dart';

import '../../state/tidings_settings.dart';
import '../../theme/account_accent.dart';
import '../../theme/color_tokens.dart';
import '../../theme/glass.dart';

class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.label,
    this.accent,
    this.selected = false,
    this.dense = false,
  });

  final String label;
  final Color? accent;
  final bool selected;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final accentColor = accent ?? Theme.of(context).colorScheme.primary;
    final tokens = accentTokensFor(context, accentColor);
    final textColor = selected
        ? tokens.onSurface
        : ColorTokens.textSecondary(context, 0.7);
    return GlassPanel(
      borderRadius: BorderRadius.circular(
        dense ? context.radius(12) : context.radius(14),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: dense ? context.space(10) : context.space(12),
        vertical: dense ? context.space(4) : context.space(6),
      ),
      variant: GlassVariant.pill,
      accent: selected ? tokens.base : null,
      selected: selected,
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: textColor),
      ),
    );
  }
}
