import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../state/tidings_settings.dart';
import '../../theme/color_tokens.dart';
import '../../widgets/glass/glass_text_field.dart';

class _QuillEscapeIntent extends Intent {
  const _QuillEscapeIntent();
}

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
    this.toFocusNode,
    this.recipientSummary,
    this.subjectSummary,
    this.minEditorHeight = 160,
    this.maxEditorHeight = 320,
    this.showFormattingToggle = true,
    this.editorFocusNode,
    this.subjectFocusNode,
    this.onEscape,
  });

  final QuillController controller;
  final TextEditingController toController;
  final TextEditingController ccController;
  final TextEditingController bccController;
  final TextEditingController subjectController;
  final bool showFields;
  final String placeholder;
  final FocusNode? toFocusNode;
  final String? recipientSummary;
  final String? subjectSummary;
  final double minEditorHeight;
  final double maxEditorHeight;
  final bool showFormattingToggle;
  final FocusNode? editorFocusNode;
  final FocusNode? subjectFocusNode;
  final VoidCallback? onEscape;

  @override
  State<ComposeEditor> createState() => _ComposeEditorState();
}

class _ComposeEditorState extends State<ComposeEditor> {
  late FocusNode _subjectFocusNode;
  late FocusNode _editorFocusNode;
  late FocusNode _toFocusNode;
  late bool _ownsSubjectFocusNode;
  late bool _ownsEditorFocusNode;
  late bool _ownsToFocusNode;
  bool _showToolbar = false;

  DefaultStyles _editorStyles(BuildContext context) {
    final styles = DefaultStyles.getInstance(context);
    final bodySize = Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14;
    final paragraph = styles.paragraph?.copyWith(
      style: styles.paragraph!.style.copyWith(
        fontSize: bodySize,
        height: 1.4,
      ),
    );
    final placeholder = styles.placeHolder?.copyWith(
      style: styles.placeHolder!.style.copyWith(
        fontSize: bodySize,
        color: ColorTokens.textSecondary(context),
      ),
    );
    return DefaultStyles(
      h1: styles.h1,
      h2: styles.h2,
      h3: styles.h3,
      h4: styles.h4,
      h5: styles.h5,
      h6: styles.h6,
      paragraph: paragraph ?? styles.paragraph,
      lineHeightNormal: styles.lineHeightNormal,
      lineHeightTight: styles.lineHeightTight,
      lineHeightOneAndHalf: styles.lineHeightOneAndHalf,
      lineHeightDouble: styles.lineHeightDouble,
      bold: styles.bold,
      subscript: styles.subscript,
      superscript: styles.superscript,
      italic: styles.italic,
      small: styles.small,
      underline: styles.underline,
      strikeThrough: styles.strikeThrough,
      inlineCode: styles.inlineCode,
      link: styles.link,
      color: styles.color,
      placeHolder: placeholder ?? styles.placeHolder,
      lists: styles.lists,
      quote: styles.quote,
      code: styles.code,
      indent: styles.indent,
      align: styles.align,
      leading: styles.leading,
      sizeSmall: styles.sizeSmall,
      sizeLarge: styles.sizeLarge,
      sizeHuge: styles.sizeHuge,
      palette: styles.palette,
    );
  }

  @override
  void initState() {
    super.initState();
    _toFocusNode = widget.toFocusNode ?? FocusNode();
    _subjectFocusNode = widget.subjectFocusNode ?? FocusNode();
    _editorFocusNode = widget.editorFocusNode ?? FocusNode();
    _ownsToFocusNode = widget.toFocusNode == null;
    _ownsSubjectFocusNode = widget.subjectFocusNode == null;
    _ownsEditorFocusNode = widget.editorFocusNode == null;
  }

  @override
  void didUpdateWidget(covariant ComposeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.toFocusNode != widget.toFocusNode) {
      if (_ownsToFocusNode) {
        _toFocusNode.dispose();
      }
      _toFocusNode = widget.toFocusNode ?? FocusNode();
      _ownsToFocusNode = widget.toFocusNode == null;
    }
    if (oldWidget.subjectFocusNode != widget.subjectFocusNode) {
      if (_ownsSubjectFocusNode) {
        _subjectFocusNode.dispose();
      }
      _subjectFocusNode = widget.subjectFocusNode ?? FocusNode();
      _ownsSubjectFocusNode = widget.subjectFocusNode == null;
    }
    if (oldWidget.editorFocusNode != widget.editorFocusNode) {
      if (_ownsEditorFocusNode) {
        _editorFocusNode.dispose();
      }
      _editorFocusNode = widget.editorFocusNode ?? FocusNode();
      _ownsEditorFocusNode = widget.editorFocusNode == null;
    }
  }

  @override
  void dispose() {
    if (_ownsToFocusNode) {
      _toFocusNode.dispose();
    }
    if (_ownsSubjectFocusNode) {
      _subjectFocusNode.dispose();
    }
    if (_ownsEditorFocusNode) {
      _editorFocusNode.dispose();
    }
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
    final textStyle = Theme.of(context).textTheme.bodyMedium;
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
              child: GlassTextField(
                controller: widget.toController,
                hintText: 'To',
                focusNode: _toFocusNode,
                textInputAction: TextInputAction.next,
                textStyle: textStyle,
              ),
            ),
            SizedBox(height: context.space(10)),
            Row(
              children: [
                Expanded(
                  child: FocusTraversalOrder(
                    order: const NumericFocusOrder(2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GlassTextField(
                          controller: widget.ccController,
                          hintText: 'Cc',
                          textInputAction: TextInputAction.next,
                          textStyle: textStyle,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: context.space(10)),
                Expanded(
                  child: FocusTraversalOrder(
                    order: const NumericFocusOrder(3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GlassTextField(
                          controller: widget.bccController,
                          hintText: 'Bcc',
                          textInputAction: TextInputAction.next,
                          textStyle: textStyle,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.space(10)),
            FocusTraversalOrder(
              order: const NumericFocusOrder(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlassTextField(
                    controller: widget.subjectController,
                    hintText: 'Subject',
                    focusNode: _subjectFocusNode,
                    textInputAction: TextInputAction.next,
                    textStyle: textStyle,
                    onSubmitted: (_) => _editorFocusNode.requestFocus(),
                  ),
                ],
              ),
            ),
            SizedBox(height: context.space(10)),
          ],
          if (widget.showFormattingToggle) ...[
            FocusTraversalOrder(
              order: const NumericFocusOrder(5),
              child: Row(
                children: [
                  const Spacer(),
                  IconButton(
                    onPressed: _toggleToolbar,
                    icon: Icon(
                      _showToolbar
                          ? Icons.close_fullscreen_rounded
                          : Icons.text_format_rounded,
                    ),
                    tooltip:
                        _showToolbar ? 'Hide formatting' : 'Show formatting',
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
            SizedBox(height: context.space(8)),
          ],
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
                  customStyles: _editorStyles(context),
                  customShortcuts: {
                    const SingleActivator(LogicalKeyboardKey.escape):
                        const _QuillEscapeIntent(),
                  },
                  customActions: {
                    _QuillEscapeIntent: CallbackAction<_QuillEscapeIntent>(
                      onInvoke: (intent) {
                        if (_editorFocusNode.hasFocus) {
                          _editorFocusNode.unfocus();
                        } else {
                          FocusManager.instance.primaryFocus?.unfocus();
                        }
                        widget.onEscape?.call();
                        return null;
                      },
                    ),
                  },
                  onKeyPressed: (event, _) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.escape) {
                      if (_editorFocusNode.hasFocus) {
                        _editorFocusNode.unfocus();
                      } else {
                        FocusManager.instance.primaryFocus?.unfocus();
                      }
                      widget.onEscape?.call();
                      return KeyEventResult.handled;
                    }
                    return null;
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
