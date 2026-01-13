import 'package:flutter/material.dart';

class AuthFields extends StatelessWidget {
  const AuthFields({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (enabled) {
      return child;
    }
    return Opacity(
      opacity: 0.45,
      child: IgnorePointer(
        ignoring: true,
        child: child,
      ),
    );
  }
}
