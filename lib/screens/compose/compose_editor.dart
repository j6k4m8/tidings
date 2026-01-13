import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../state/tidings_settings.dart';
import '../../theme/color_tokens.dart';

class ComposeEditor extends StatefulWidget {
  const ComposeEditor({
    super.key,
    required this.controller,
    required this.toController,
    required this.ccController,
    required this.bccController,
    required this.subjectController,
    required this.showFields,
    required this.placeholder,
    this.recipientSummary,
    this.subjectSummary,
    this.minEditorHeight = 160,
    this.maxEditorHeight = 320,
  });

  final QuillController controller;
  final TextEditingController toController;
  final TextEditingController ccController;
  final TextEditingController bccController;
  final TextEditingController subjectController;
  final bool showFields;
  final String placeholder;
  final String? recipientSummary;
  final String? subjectSummary;
  final double minEditorHeight;
  final double maxEditorHeight;

  @override
  State<ComposeEditor> createState() => _ComposeEditorState();
}

class _ComposeEditorState extends State<ComposeEditor> {
  final FocusNode _subjectFocusNode = FocusNode();
  final FocusNode _editorFocusNode = FocusNode();
  bool _showToolbar = false;

  @override
  void dispose() {
    _subjectFocusNode.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  void _toggleToolbar() {
    setState(() {
      _showToolbar = !_showToolbar;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showFields = widget.showFields;
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!showFields && widget.recipientSummary != null) ...[
            Text(
              widget.recipientSummary!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ColorTokens.textSecondary(context),
                  ),
            ),
            if (widget.subjectSummary != null) ...[
              SizedBox(height: context.space(6)),
              Text(
                widget.subjectSummary!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ColorTokens.textSecondary(context),
                    ),
              ),
            ],
            SizedBox(height: context.space(10)),
          ],
          if (showFields) ...[
            FocusTraversalOrder(
              order: const NumericFocusOrder(1),
              child: TextField(
                controller: widget.toController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'To',
                  hintText: 'name@example.com',
                ),
              ),
            ),
            SizedBox(height: context.space(10)),
            Row(
              children: [
                Expanded(
                  child: FocusTraversalOrder(
                    order: const NumericFocusOrder(2),
                    child: TextField(
                      controller: widget.ccController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Cc'),
                    ),
                  ),
                ),
                SizedBox(width: context.space(10)),
                Expanded(
                  child: FocusTraversalOrder(
                    order: const NumericFocusOrder(3),
                    child: TextField(
                      controller: widget.bccController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Bcc'),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.space(10)),
            FocusTraversalOrder(
              order: const NumericFocusOrder(4),
              child: TextField(
                controller: widget.subjectController,
                focusNode: _subjectFocusNode,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Subject'),
                onSubmitted: (_) => _editorFocusNode.requestFocus(),
              ),
            ),
            SizedBox(height: context.space(10)),
          ],
          FocusTraversalOrder(
            order: const NumericFocusOrder(5),
            child: Row(
              children: [
                Text(
                  'Formatting',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: ColorTokens.textSecondary(context, 0.7),
                      ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _toggleToolbar,
                  icon: Icon(
                    _showToolbar
                        ? Icons.close_fullscreen_rounded
                        : Icons.text_format_rounded,
                  ),
                  label: Text(_showToolbar ? 'Hide' : 'Format'),
                ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _showToolbar
                ? QuillSimpleToolbar(
                    controller: widget.controller,
                    config: const QuillSimpleToolbarConfig(
                      showUndo: false,
                      showRedo: false,
                      showFontFamily: false,
                      showFontSize: false,
                      showColorButton: false,
                      showBackgroundColorButton: false,
                      showSearchButton: false,
                      showSubscript: false,
                      showSuperscript: false,
                      showCodeBlock: false,
                      showQuote: false,
                      showIndent: false,
                      showListNumbers: false,
                      showListBullets: false,
                      showListCheck: false,
                      showInlineCode: false,
                      showHeaderStyle: false,
                      showClearFormat: false,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          SizedBox(height: context.space(10)),
          FocusTraversalOrder(
            order: const NumericFocusOrder(6),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: widget.minEditorHeight,
              maxHeight: widget.maxEditorHeight,
            ),
            child: QuillEditor.basic(
              controller: widget.controller,
              focusNode: _editorFocusNode,
              config: QuillEditorConfig(
                placeholder: widget.placeholder,
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }
}
