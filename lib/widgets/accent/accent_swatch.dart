import 'package:flutter/material.dart';

import '../../state/tidings_settings.dart';

class AccentSwatch extends StatelessWidget {
  const AccentSwatch({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.tidingsSettings.densityScale;
    double space(double value) => value * densityScale;
    final ringColor =
        selected ? Theme.of(context).colorScheme.primary : Colors.transparent;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: space(24).clamp(18.0, 30.0),
              height: space(24).clamp(18.0, 30.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(
                  color: ringColor,
                  width: 2,
                ),
              ),
            ),
            SizedBox(width: space(8)),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
