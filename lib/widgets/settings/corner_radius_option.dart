import 'package:flutter/material.dart';

import '../../state/tidings_settings.dart';
import '../../theme/color_tokens.dart';

class CornerRadiusOption extends StatelessWidget {
  const CornerRadiusOption({
    super.key,
    required this.label,
    required this.radius,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final double radius;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.tidingsSettings.densityScale;
    double space(double value) => value * densityScale;
    final borderColor = selected
        ? Theme.of(context).colorScheme.primary
        : ColorTokens.border(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: space(52).clamp(42.0, 60.0),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1)
                : Colors.transparent,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(radius),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected ? Theme.of(context).colorScheme.primary : null,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
          ),
        ),
      ),
    );
  }
}
