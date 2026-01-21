import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/keyboard_shortcut.dart';

class ShortcutRecorder extends StatefulWidget {
  const ShortcutRecorder({
    super.key,
    required this.shortcut,
    required this.onChanged,
  });

  final KeyboardShortcut shortcut;
  final ValueChanged<KeyboardShortcut> onChanged;

  @override
  State<ShortcutRecorder> createState() => _ShortcutRecorderState();
}

class _ShortcutRecorderState extends State<ShortcutRecorder> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'ShortcutRecorder');
  bool _isRecording = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
    });
    _focusNode.requestFocus();
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
    });
    _focusNode.unfocus();
  }

  void _handleKey(KeyEvent event) {
    if (!_isRecording || event is! KeyDownEvent) {
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _stopRecording();
      return;
    }
    if (_isModifierKey(event.logicalKey)) {
      return;
    }
    final keyboard = HardwareKeyboard.instance;
    final shortcut = KeyboardShortcut(
      key: event.logicalKey,
      meta: keyboard.isMetaPressed,
      control: keyboard.isControlPressed,
      alt: keyboard.isAltPressed,
      shift: keyboard.isShiftPressed,
    );
    widget.onChanged(shortcut);
    _stopRecording();
  }

  bool _isModifierKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.shift ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.alt ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight ||
        key == LogicalKeyboardKey.meta;
  }

  @override
  Widget build(BuildContext context) {
    final label = _isRecording ? 'Press keys…' : widget.shortcut.label();
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        onPressed: _isRecording ? _stopRecording : _startRecording,
        child: Text(label),
      ),
    );
  }
}
