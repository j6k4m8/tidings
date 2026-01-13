import 'package:flutter/material.dart';

class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.bottomPadding = 12,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            decoration: InputDecoration(hintText: hintText),
          ),
        ],
      ),
    );
  }
}
