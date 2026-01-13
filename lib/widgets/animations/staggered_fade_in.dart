import 'package:flutter/material.dart';

class StaggeredFadeIn extends StatelessWidget {
  const StaggeredFadeIn({
    super.key,
    required this.index,
    required this.child,
    this.duration = const Duration(milliseconds: 700),
    this.step = 0.08,
    this.offset = 16,
  });

  final int index;
  final Widget child;
  final Duration duration;
  final double step;
  final double offset;

  @override
  Widget build(BuildContext context) {
    final start = (index * step).clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, offset * (1 - value)),
            child: child,
          ),
        );
      },
    );
  }
}
