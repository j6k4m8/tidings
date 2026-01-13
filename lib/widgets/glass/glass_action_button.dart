import 'package:flutter/material.dart';

import '../../state/tidings_settings.dart';
import '../../theme/account_accent.dart';
import '../../theme/glass.dart';

class GlassActionButton extends StatelessWidget {
  const GlassActionButton({
    super.key,
    required this.accent,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final Color accent;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = accentTokensFor(context, accent);
    return GestureDetector(
      onTap: onTap,
      child: GlassPanel(
        borderRadius: BorderRadius.circular(context.radius(24)),
        padding: EdgeInsets.symmetric(
          horizontal: context.space(16),
          vertical: context.space(12),
        ),
        variant: GlassVariant.action,
        accent: tokens.base,
        selected: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: tokens.onSurface),
            SizedBox(width: context.space(8)),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: tokens.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
