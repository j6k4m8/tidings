import 'package:flutter/material.dart';

import '../theme/color_tokens.dart';

class TidingsBackground extends StatelessWidget {
  const TidingsBackground({
    super.key,
    required this.accent,
    required this.child,
  });

  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = ColorTokens.panelBackground(context);
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: base,
            ),
          ),
        ),
        child,
      ],
    );
  }
}
