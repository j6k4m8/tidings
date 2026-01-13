import 'package:flutter/material.dart';

import '../../state/tidings_settings.dart';

class AccountAvatar extends StatelessWidget {
  const AccountAvatar({
    super.key,
    required this.name,
    required this.accent,
    this.onTap,
    this.radius,
    this.showRing = false,
    this.ringPadding,
    this.ringWidth = 2,
  });

  final String name;
  final Color accent;
  final VoidCallback? onTap;
  final double? radius;
  final bool showRing;
  final double? ringPadding;
  final double ringWidth;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim().substring(0, 1);
    final avatar = CircleAvatar(
      radius: radius ?? context.space(18),
      backgroundColor: accent.withValues(alpha: 0.2),
      child: Text(
        letter.toUpperCase(),
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
    final wrapped = showRing
        ? Container(
            padding: EdgeInsets.all(ringPadding ?? context.space(4)),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: ringWidth),
            ),
            child: avatar,
          )
        : avatar;
    if (onTap == null) {
      return wrapped;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: wrapped,
    );
  }
}
