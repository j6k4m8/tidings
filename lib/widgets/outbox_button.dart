import 'package:flutter/material.dart';

/// Badged outbox icon button used in both the wide top-bar and the compact
/// sidebar rail.  Shows a count badge when [count] > 0.
class OutboxButton extends StatelessWidget {
  const OutboxButton({
    super.key,
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
