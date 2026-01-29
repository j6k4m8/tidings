import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../state/tidings_settings.dart';
import 'compose_editor.dart';

class ComposeForm extends StatelessWidget {
  const ComposeForm({
    super.key,
    required this.controller,
    required this.toController,
    required this.ccController,
    required this.bccController,
    required this.subjectController,
    required this.showFields,
    required this.placeholder,
    this.toFocusNode,
    this.editorFocusNode,
    this.subjectFocusNode,
    this.minEditorHeight = 160,
    this.maxEditorHeight = 320,
    this.showFormattingToggle = true,
    this.onEscape,
    this.showEditorBorder = false,
    this.editorBorderColor,
    this.editorBorderRadius,
    this.editorPadding,
    this.toolbarIconSize,
    this.toolbarIconPadding,
    this.toolbarButtonConstraints,
    this.toolbarButtonStyle,
    this.toolbarDecoration,
    this.toolbarSize,
    this.toolbarSectionSpacing,
    this.toolbarMultiRowsDisplay,
    this.footer,
    this.errorText,
    this.errorLabel,
    this.onCopyError,
  });

  final QuillController controller;
  final TextEditingController toController;
  final TextEditingController ccController;
  final TextEditingController bccController;
  final TextEditingController subjectController;
  final bool showFields;
  final String placeholder;
  final FocusNode? toFocusNode;
  final FocusNode? editorFocusNode;
  final FocusNode? subjectFocusNode;
  final double minEditorHeight;
  final double maxEditorHeight;
  final bool showFormattingToggle;
  final VoidCallback? onEscape;
  final bool showEditorBorder;
  final Color? editorBorderColor;
  final BorderRadius? editorBorderRadius;
  final EdgeInsetsGeometry? editorPadding;
  final double? toolbarIconSize;
  final EdgeInsetsGeometry? toolbarIconPadding;
  final BoxConstraints? toolbarButtonConstraints;
  final ButtonStyle? toolbarButtonStyle;
  final Decoration? toolbarDecoration;
  final double? toolbarSize;
  final double? toolbarSectionSpacing;
  final bool? toolbarMultiRowsDisplay;
  final Widget? footer;
  final String? errorText;
  final String? errorLabel;
  final VoidCallback? onCopyError;

  @override
  Widget build(BuildContext context) {
    final error = errorText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ComposeEditor(
          controller: controller,
          toController: toController,
          ccController: ccController,
          bccController: bccController,
          subjectController: subjectController,
          showFields: showFields,
          placeholder: placeholder,
          toFocusNode: toFocusNode,
          editorFocusNode: editorFocusNode,
          subjectFocusNode: subjectFocusNode,
          minEditorHeight: minEditorHeight,
          maxEditorHeight: maxEditorHeight,
          showFormattingToggle: showFormattingToggle,
          onEscape: onEscape,
          showEditorBorder: showEditorBorder,
          editorBorderColor: editorBorderColor,
          editorBorderRadius: editorBorderRadius,
          editorPadding: editorPadding,
          toolbarIconSize: toolbarIconSize,
          toolbarIconPadding: toolbarIconPadding,
          toolbarButtonConstraints: toolbarButtonConstraints,
          toolbarButtonStyle: toolbarButtonStyle,
          toolbarDecoration: toolbarDecoration,
          toolbarSize: toolbarSize,
          toolbarSectionSpacing: toolbarSectionSpacing,
          toolbarMultiRowsDisplay: toolbarMultiRowsDisplay,
        ),
        if (footer != null) ...[
          SizedBox(height: context.space(12)),
          footer!,
        ],
        if (error != null) ...[
          SizedBox(height: context.space(8)),
          Row(
            children: [
              Text(
                errorLabel ?? 'Send error',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.redAccent,
                    ),
              ),
              const Spacer(),
              if (onCopyError != null)
                IconButton(
                  onPressed: onCopyError,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: 'Copy error',
                ),
            ],
          ),
          SelectableText(
            error,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.redAccent),
          ),
        ],
      ],
    );
  }
}
