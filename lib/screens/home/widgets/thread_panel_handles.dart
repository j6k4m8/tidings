import 'package:flutter/material.dart';

import '../../../state/tidings_settings.dart';
import '../../../theme/color_tokens.dart';

class ThreadPanelResizeHandle extends StatelessWidget {
  const ThreadPanelResizeHandle({
    super.key,
    required this.onDragUpdate,
    this.onDragEnd,
  });

  final ValueChanged<double> onDragUpdate;
  final VoidCallback? onDragEnd;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) => onDragUpdate(details.delta.dx),
        onHorizontalDragEnd: (_) => onDragEnd?.call(),
        child: SizedBox(
          width: context.space(12),
          child: Center(
            child: Container(
              width: 3,
              height: context.space(48),
              decoration: BoxDecoration(
                color: ColorTokens.border(context, 0.2),
                borderRadius: BorderRadius.circular(context.radius(8)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ThreadPanelHint extends StatelessWidget {
  const ThreadPanelHint({
    super.key,
    required this.width,
    required this.onTap,
    required this.onDragUpdate,
    this.onDragEnd,
  });

  final double width;
  final VoidCallback onTap;
  final ValueChanged<double> onDragUpdate;
  final VoidCallback? onDragEnd;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        onHorizontalDragUpdate: (details) => onDragUpdate(details.delta.dx),
        onHorizontalDragEnd: (_) => onDragEnd?.call(),
        child: SizedBox(
          width: width,
          child: Center(
            child: Container(
              width: 3,
              height: context.space(48),
              decoration: BoxDecoration(
                color: ColorTokens.border(context, 0.2),
                borderRadius: BorderRadius.circular(context.radius(8)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
