import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../state/tidings_settings.dart';
import '../../theme/color_tokens.dart';
import '../../widgets/recipient_field.dart';

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
    this.quotedText,
    this.quotedTooltip = 'Show quoted',
    this.showQuotedInitially = false,
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
  final String? quotedText;
  final String quotedTooltip;
  final bool showQuotedInitially;

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
  // Internal focus nodes for Cc/Bcc (always owned by this state)
  final FocusNode _ccFocusNode = FocusNode();
  final FocusNode _bccFocusNode = FocusNode();
  bool _showQuoted = false;
  // Cc/Bcc visibility — shown when populated or focused, hidden when empty+blurred
  bool _showCc = false;
  bool _showBcc = false;

  DefaultStyles _editorStyles(BuildContext context) {
    final styles = DefaultStyles.getInstance(context);
    final bodySize = Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14;
    final paragraph = styles.paragraph?.copyWith(
      style: styles.paragraph!.style.copyWith(fontSize: bodySize, height: 1.4),
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
    _showQuoted = widget.showQuotedInitially;
    // Show Cc/Bcc if already populated (e.g. restored draft or reply-all).
    _showCc = widget.ccController.text.isNotEmpty;
    _showBcc = widget.bccController.text.isNotEmpty;
    // Keep visibility in sync when controllers change externally.
    widget.ccController.addListener(_onCcChanged);
    widget.bccController.addListener(_onBccChanged);
    // Show when focus enters the hidden field (e.g. Tab key from To).
    _ccFocusNode.addListener(_onCcFocusChanged);
    _bccFocusNode.addListener(_onBccFocusChanged);
  }

  void _onControllerChanged(
    TextEditingController ctrl,
    bool showing,
    void Function(bool) setShow,
  ) {
    if (ctrl.text.isNotEmpty && !showing) setShow(true);
  }

  void _onCcChanged() =>
      _onControllerChanged(widget.ccController, _showCc, (v) => setState(() => _showCc = v));

  void _onBccChanged() =>
      _onControllerChanged(widget.bccController, _showBcc, (v) => setState(() => _showBcc = v));

  void _onFieldFocusChanged(
    FocusNode node,
    TextEditingController ctrl,
    bool showing,
    void Function(bool) setShow,
  ) {
    if (node.hasFocus && !showing) {
      setShow(true);
    } else if (!node.hasFocus && showing && ctrl.text.isEmpty) {
      setShow(false);
    }
  }

  void _onCcFocusChanged() => _onFieldFocusChanged(
        _ccFocusNode, widget.ccController, _showCc,
        (v) => setState(() => _showCc = v),
      );

  void _onBccFocusChanged() => _onFieldFocusChanged(
        _bccFocusNode, widget.bccController, _showBcc,
        (v) => setState(() => _showBcc = v),
      );

  @override
  void didUpdateWidget(covariant ComposeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ccController != widget.ccController) {
      oldWidget.ccController.removeListener(_onCcChanged);
      widget.ccController.addListener(_onCcChanged);
      if (widget.ccController.text.isNotEmpty) setState(() => _showCc = true);
    }
    if (oldWidget.bccController != widget.bccController) {
      oldWidget.bccController.removeListener(_onBccChanged);
      widget.bccController.addListener(_onBccChanged);
      if (widget.bccController.text.isNotEmpty) setState(() => _showBcc = true);
    }
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
    if (oldWidget.quotedText != widget.quotedText) {
      final nextText = widget.quotedText?.trim();
      if (nextText == null || nextText.isEmpty) {
        _showQuoted = false;
      } else if (_showQuoted == false && widget.showQuotedInitially) {
        _showQuoted = true;
      }
    }
  }

  @override
  void dispose() {
    widget.ccController.removeListener(_onCcChanged);
    widget.bccController.removeListener(_onBccChanged);
    _ccFocusNode.removeListener(_onCcFocusChanged);
    _bccFocusNode.removeListener(_onBccFocusChanged);
    if (_ownsToFocusNode) {
      _toFocusNode.dispose();
    }
    if (_ownsSubjectFocusNode) {
      _subjectFocusNode.dispose();
    }
    if (_ownsEditorFocusNode) {
      _editorFocusNode.dispose();
    }
    _ccFocusNode.dispose();
    _bccFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showFields = widget.showFields;
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: ColorTokens.textSecondary(context, 0.5),
        );
    final fieldStyle = Theme.of(context).textTheme.bodyMedium;
    final dividerColor = ColorTokens.border(context, 0.10);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          // ── Recipient/subject summary (collapsed mode) ─────────────────
          if (!showFields && widget.recipientSummary != null) ...[
            Text(
              widget.recipientSummary!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ColorTokens.textSecondary(context),
              ),
            ),
            if (widget.subjectSummary != null) ...[
              SizedBox(height: context.space(4)),
              Text(
                widget.subjectSummary!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ColorTokens.textSecondary(context),
                ),
              ),
            ],
            SizedBox(height: context.space(10)),
          ],
          // ── Fields (To / Cc / Bcc / Subject) ──────────────────────────
          if (showFields) ...[
            // To row — with Cc/Bcc reveal buttons on the right
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: RecipientField(
                    controller: widget.toController,
                    label: 'To',
                    focusNode: _toFocusNode,
                    // Tab advances to Cc if visible, otherwise Bcc if visible,
                    // otherwise Subject.
                    nextFocusNode: _showCc
                        ? _ccFocusNode
                        : _showBcc
                            ? _bccFocusNode
                            : _subjectFocusNode,
                    textStyle: fieldStyle,
                    labelStyle: labelStyle,
                  ),
                ),
                // Cc / Bcc reveal buttons (hidden once the field is shown)
                if (!_showCc || !_showBcc) ...[
                  if (!_showCc)
                    _CcBccButton(
                      label: 'Cc',
                      onTap: () {
                        setState(() => _showCc = true);
                        // Focus the Cc field on the next frame so the widget
                        // is in the tree before we request focus.
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _ccFocusNode.requestFocus();
                        });
                      },
                    ),
                  if (!_showBcc)
                    _CcBccButton(
                      label: 'Bcc',
                      onTap: () {
                        setState(() => _showBcc = true);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _bccFocusNode.requestFocus();
                        });
                      },
                    ),
                  const SizedBox(width: 4),
                ],
              ],
            ),
            Divider(height: 1, thickness: 1, color: dividerColor),
            // Cc — only shown when populated or focused
            if (_showCc) ...[
              RecipientField(
                controller: widget.ccController,
                label: 'Cc',
                focusNode: _ccFocusNode,
                nextFocusNode: _showBcc ? _bccFocusNode : _subjectFocusNode,
                textStyle: fieldStyle,
                labelStyle: labelStyle,
              ),
              Divider(height: 1, thickness: 1, color: dividerColor),
            ],
            // Bcc — only shown when populated or focused
            if (_showBcc) ...[
              RecipientField(
                controller: widget.bccController,
                label: 'Bcc',
                focusNode: _bccFocusNode,
                nextFocusNode: _subjectFocusNode,
                textStyle: fieldStyle,
                labelStyle: labelStyle,
              ),
              Divider(height: 1, thickness: 1, color: dividerColor),
            ],
            // Subject — large, prominent, no label
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: TextField(
                controller: widget.subjectController,
                focusNode: _subjectFocusNode,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _editorFocusNode.requestFocus(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                decoration: InputDecoration.collapsed(
                  hintText: 'Subject',
                  hintStyle:
                      Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: ColorTokens.textSecondary(context, 0.3),
                          ),
                ),
              ),
            ),
            Divider(height: 1, thickness: 1, color: dividerColor),
            SizedBox(height: context.space(8)),
          ],
          // ── Body editor ───────────────────────────────────────────────
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
          // ── Quoted content ─────────────────────────────────────────────
          if (widget.quotedText != null &&
              widget.quotedText!.trim().isNotEmpty) ...[
            SizedBox(height: context.space(8)),
            Align(
              alignment: Alignment.centerLeft,
              child: Tooltip(
                message: _showQuoted ? 'Hide quoted' : widget.quotedTooltip,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _showQuoted = !_showQuoted;
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    _showQuoted ? 'Hide quoted' : '···',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ColorTokens.textSecondary(context),
                        ),
                  ),
                ),
              ),
            ),
            if (_showQuoted) ...[
              SizedBox(height: context.space(6)),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(context.space(10)),
                decoration: BoxDecoration(
                  color: ColorTokens.cardFill(context, 0.08),
                  borderRadius: BorderRadius.circular(context.radius(12)),
                  border: Border.all(
                    color: ColorTokens.border(context, 0.18),
                  ),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: context.space(180),
                  ),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      child: SelectableText(
                        widget.quotedText!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: ColorTokens.textSecondary(context),
                              height: 1.4,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      );
  }
}

/// Small tappable label used to reveal the Cc or Bcc field.
class _CcBccButton extends StatelessWidget {
  const _CcBccButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ColorTokens.textSecondary(context, 0.5),
              ),
        ),
      ),
    );
  }
}
