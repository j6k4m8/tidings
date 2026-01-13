import 'package:flutter/material.dart';

import '../../state/tidings_settings.dart';
import '../../theme/color_tokens.dart';

class GlassTextField extends StatelessWidget {
  const GlassTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.keyboardType,
    this.textStyle,
  });

  final TextEditingController controller;
  final String hintText;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 0,
        vertical: context.space(2),
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: ColorTokens.border(context, 0.16)),
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        keyboardType: keyboardType,
        style: textStyle,
        decoration: InputDecoration.collapsed(
          hintText: hintText,
          hintStyle: textStyle?.copyWith(
                color: ColorTokens.textSecondary(context, 0.6),
              ) ??
              Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ColorTokens.textSecondary(context, 0.6),
                  ),
        ),
      ),
    );
  }
}
