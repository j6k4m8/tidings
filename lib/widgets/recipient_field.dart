import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/color_tokens.dart';

/// A text field that tokenises email addresses into chips.
///
/// Typing a comma, semicolon, or Tab confirms the current input as a chip.
/// Backspace on an empty input un-chips the last entry back into editable text.
class RecipientField extends StatefulWidget {
  const RecipientField({
    super.key,
    required this.controller,
    required this.label,
    this.focusNode,
    this.nextFocusNode,
    this.textStyle,
    this.labelStyle,
    this.onChanged,
  });

  /// Plain-text backing controller — comma-separated confirmed chips.
  final TextEditingController controller;

  /// Label shown on the left (e.g. "To", "Cc", "Bcc").
  final String label;

  /// External focus node. When provided this widget forwards focus to its
  /// internal text field when this node gains focus.
  final FocusNode? focusNode;

  /// Focus node to advance to on Tab.
  final FocusNode? nextFocusNode;

  final TextStyle? textStyle;
  final TextStyle? labelStyle;
  final VoidCallback? onChanged;

  @override
  State<RecipientField> createState() => RecipientFieldState();
}

class RecipientFieldState extends State<RecipientField> {
  // The actual text field focus node (always owned by this state).
  final FocusNode _inputFocusNode = FocusNode();
  final TextEditingController _inputController = TextEditingController();
  final List<String> _chips = [];
  bool _ignoringControllerChange = false;

  @override
  void initState() {
    super.initState();
    // Forward focus from the external node into our input node.
    widget.focusNode?.addListener(_onExternalFocusChange);
    _syncFromController();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant RecipientField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onExternalFocusChange);
      widget.focusNode?.addListener(_onExternalFocusChange);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      _syncFromController();
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.focusNode?.removeListener(_onExternalFocusChange);
    widget.controller.removeListener(_onControllerChanged);
    _inputFocusNode.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _onExternalFocusChange() {
    if (widget.focusNode?.hasFocus == true) {
      _inputFocusNode.requestFocus();
    }
  }

  // ── Sync ──────────────────────────────────────────────────────────────────

  void _onControllerChanged() {
    if (_ignoringControllerChange) return;
    _syncFromController();
  }

  void _syncFromController() {
    final raw = widget.controller.text;
    final parts = raw
        .split(RegExp(r'[,;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (!_listsEqual(parts, _chips)) {
      setState(() {
        _chips
          ..clear()
          ..addAll(parts);
        _inputController.text = '';
      });
    }
  }

  void _pushToController() {
    _ignoringControllerChange = true;
    final all = [
      ..._chips,
      if (_inputController.text.trim().isNotEmpty) _inputController.text.trim(),
    ];
    widget.controller.text = all.join(', ');
    widget.onChanged?.call();
    _ignoringControllerChange = false;
  }

  // ── Chip management ───────────────────────────────────────────────────────

  void _commitInput({bool advance = false}) {
    final text =
        _inputController.text.trim().replaceAll(RegExp(r'[,;]+$'), '').trim();
    if (text.isNotEmpty) {
      setState(() {
        _chips.add(text);
        _inputController.clear();
      });
      _pushToController();
    }
    if (advance && widget.nextFocusNode != null) {
      widget.nextFocusNode!.requestFocus();
    } else if (advance) {
      _inputFocusNode.nextFocus();
    }
  }

  /// Removes the last chip and puts its text back into the input field.
  void _unchipLast() {
    if (_chips.isNotEmpty) {
      final last = _chips.last;
      setState(() {
        _chips.removeLast();
        _inputController.text = last;
        _inputController.selection = TextSelection.collapsed(
          offset: last.length,
        );
      });
      _pushToController();
    }
  }

  void _removeChip(int index) {
    setState(() {
      _chips.removeAt(index);
    });
    _pushToController();
    _inputFocusNode.requestFocus();
  }

  /// Removes a chip at [index] and puts its text back into the input field.
  void _unchipAt(int index) {
    final text = _chips[index];
    setState(() {
      _chips.removeAt(index);
      _inputController.text = text;
      _inputController.selection = TextSelection.collapsed(
        offset: text.length,
      );
    });
    _pushToController();
    _inputFocusNode.requestFocus();
  }

  // ── Key handling ──────────────────────────────────────────────────────────

  KeyEventResult _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    // Tab — commit and advance
    if (key == LogicalKeyboardKey.tab) {
      _commitInput(advance: true);
      return KeyEventResult.handled;
    }
    // Comma / semicolon / enter — commit in place
    if (key == LogicalKeyboardKey.comma ||
        key == LogicalKeyboardKey.semicolon ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _commitInput();
      return KeyEventResult.handled;
    }
    // Backspace on empty input — un-chip the last entry
    if (key == LogicalKeyboardKey.backspace &&
        _inputController.text.isEmpty) {
      _unchipLast();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final chipBg = ColorTokens.cardFill(context, 0.14);
    final chipBorder = ColorTokens.border(context, 0.18);
    final chipTextStyle =
        (widget.textStyle ?? Theme.of(context).textTheme.bodyMedium)
            ?.copyWith(fontSize: 12.5);
    final inputStyle =
        widget.textStyle ?? Theme.of(context).textTheme.bodyMedium;

    return GestureDetector(
      onTap: _inputFocusNode.requestFocus,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Label
            SizedBox(
              width: 40,
              child: Text(widget.label, style: widget.labelStyle),
            ),
            // Chips + inline input
            Expanded(
              child: Wrap(
                spacing: 5,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (int i = 0; i < _chips.length; i++)
                    _Chip(
                      label: _chips[i],
                      textStyle: chipTextStyle,
                      background: chipBg,
                      border: chipBorder,
                      onRemove: () => _removeChip(i),
                      onEdit: () => _unchipAt(i),
                    ),
                  // Inline text input — owns the real focus
                  IntrinsicWidth(
                    stepWidth: 80,
                    child: Focus(
                      onKeyEvent: (node, event) => _handleKey(event),
                      child: TextField(
                      controller: _inputController,
                      focusNode: _inputFocusNode,
                      style: inputStyle,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration.collapsed(hintText: ''),
                      onChanged: (text) {
                        // Handle paste that includes delimiters
                        if (text.contains(',') || text.contains(';')) {
                          final parts = text
                              .split(RegExp(r'[,;]'))
                              .map((s) => s.trim())
                              .where((s) => s.isNotEmpty)
                              .toList();
                          final endsWithDelim =
                              text.endsWith(',') || text.endsWith(';');
                          if (parts.length > 1 ||
                              (parts.length == 1 && endsWithDelim)) {
                            setState(() {
                              _chips.addAll(parts);
                              _inputController.clear();
                            });
                            _pushToController();
                          }
                        }
                      },
                      minLines: 1,
                      maxLines: 1,
                    ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.onRemove,
    required this.onEdit,
    this.textStyle,
    this.background,
    this.border,
  });

  final String label;
  final VoidCallback onRemove;
  final VoidCallback onEdit;
  final TextStyle? textStyle;
  final Color? background;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 3, 5, 3),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border ?? Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: textStyle),
            const SizedBox(width: 3),
            GestureDetector(
              onTap: onRemove,
              child: Icon(
                Icons.close_rounded,
                size: 11,
                color: textStyle?.color?.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _listsEqual(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
