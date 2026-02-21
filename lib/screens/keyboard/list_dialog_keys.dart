import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared [Focus.onKeyEvent] handler for the keyboard-navigable list dialogs
/// (command palette, go-to folder, move-to-folder).
///
/// Arrow keys move the selection, Enter confirms, Escape dismisses.
///
/// [listLength] is the current number of visible (filtered) items.
/// [onMove] is called with +1 (down) or -1 (up).
/// [onEnter] is called when Enter is pressed and [listLength] > 0.
/// [onEscape] is called when Escape is pressed (default: [Navigator.maybePop]).
KeyEventResult handleListDialogKey({
  required KeyEvent event,
  required int listLength,
  required void Function(int delta) onMove,
  required VoidCallback onEnter,
  VoidCallback? onEscape,
  required BuildContext context,
}) {
  if (event is! KeyDownEvent) return KeyEventResult.ignored;

  final key = event.logicalKey;

  if (key == LogicalKeyboardKey.escape) {
    (onEscape ?? () => Navigator.of(context).maybePop())();
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.arrowDown) {
    onMove(1);
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.arrowUp) {
    onMove(-1);
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.enter && listLength > 0) {
    onEnter();
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}
