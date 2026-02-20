import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'keyboard_shortcut.dart';

enum ShortcutAction {
  compose,
  reply,
  replyAll,
  forward,
  archive,
  moveToFolder,
  toggleRead,
  commandPalette,
  goTo,
  goToAccount,
  focusSearch,
  openSettings,
  sendMessage,
  openThread,
  toggleSidebar,
  navigateNext,
  navigatePrev,
  showShortcuts,
}

@immutable
class ShortcutDefinition {
  const ShortcutDefinition({
    required this.action,
    required this.label,
    required this.description,
    required this.primaryDefault,
    this.secondaryDefault,
  });

  final ShortcutAction action;
  final String label;
  final String description;
  final KeyboardShortcut primaryDefault;
  final KeyboardShortcut? secondaryDefault;
}

KeyboardShortcut _cmdOrCtrl(
  LogicalKeyboardKey key, {
  bool shift = false,
}) {
  final isApple = defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS;
  return KeyboardShortcut(
    key: key,
    meta: isApple,
    control: !isApple,
    shift: shift,
  );
}

final List<ShortcutDefinition> shortcutDefinitions = [
  ShortcutDefinition(
    action: ShortcutAction.compose,
    label: 'Compose',
    description: 'Start a new message.',
    primaryDefault: _cmdOrCtrl(LogicalKeyboardKey.keyN),
  ),
  ShortcutDefinition(
    action: ShortcutAction.reply,
    label: 'Reply',
    description: 'Reply to the selected thread.',
    primaryDefault: const KeyboardShortcut(key: LogicalKeyboardKey.keyR),
  ),
  ShortcutDefinition(
    action: ShortcutAction.replyAll,
    label: 'Reply all',
    description: 'Reply to everyone in the thread.',
    primaryDefault: const KeyboardShortcut(key: LogicalKeyboardKey.keyA),
  ),
  ShortcutDefinition(
    action: ShortcutAction.forward,
    label: 'Forward',
    description: 'Forward the selected thread.',
    primaryDefault: const KeyboardShortcut(key: LogicalKeyboardKey.keyF),
  ),
  ShortcutDefinition(
    action: ShortcutAction.archive,
    label: 'Archive',
    description: 'Move the selected thread to Archive.',
    primaryDefault: const KeyboardShortcut(key: LogicalKeyboardKey.keyE),
  ),
  ShortcutDefinition(
    action: ShortcutAction.moveToFolder,
    label: 'Move to folder',
    description: 'Move the selected thread to a folder.',
    primaryDefault: const KeyboardShortcut(key: LogicalKeyboardKey.keyV),
  ),
  ShortcutDefinition(
    action: ShortcutAction.toggleRead,
    label: 'Toggle read',
    description: 'Mark the selected thread read or unread.',
    primaryDefault: _cmdOrCtrl(LogicalKeyboardKey.keyU),
  ),
  ShortcutDefinition(
    action: ShortcutAction.commandPalette,
    label: 'Command palette',
    description: 'Open the command palette.',
    primaryDefault: _cmdOrCtrl(LogicalKeyboardKey.keyP),
  ),
  ShortcutDefinition(
    action: ShortcutAction.goTo,
    label: 'Go to folder',
    description: 'Jump to any folder across accounts.',
    primaryDefault: const KeyboardShortcut(key: LogicalKeyboardKey.keyG),
    secondaryDefault: _cmdOrCtrl(LogicalKeyboardKey.keyK),
  ),
  ShortcutDefinition(
    action: ShortcutAction.goToAccount,
    label: 'Go to folder (current account)',
    description: 'Jump to a folder in the current account.',
    primaryDefault: const KeyboardShortcut(
      key: LogicalKeyboardKey.keyG,
      shift: true,
    ),
    secondaryDefault: _cmdOrCtrl(
      LogicalKeyboardKey.keyK,
      shift: true,
    ),
  ),
  ShortcutDefinition(
    action: ShortcutAction.focusSearch,
    label: 'Focus search',
    description: 'Jump to the search field.',
    primaryDefault: _cmdOrCtrl(LogicalKeyboardKey.keyF),
  ),
  ShortcutDefinition(
    action: ShortcutAction.openSettings,
    label: 'Open settings',
    description: 'Open the settings panel.',
    primaryDefault: _cmdOrCtrl(LogicalKeyboardKey.comma),
  ),
  ShortcutDefinition(
    action: ShortcutAction.sendMessage,
    label: 'Send message',
    description: 'Send the current draft.',
    primaryDefault: _cmdOrCtrl(LogicalKeyboardKey.enter),
  ),
  ShortcutDefinition(
    action: ShortcutAction.openThread,
    label: 'Open thread',
    description: 'Open the selected thread.',
    primaryDefault: const KeyboardShortcut(key: LogicalKeyboardKey.enter),
  ),
  ShortcutDefinition(
    action: ShortcutAction.toggleSidebar,
    label: 'Toggle sidebar',
    description: 'Collapse or expand the sidebar.',
    primaryDefault: _cmdOrCtrl(LogicalKeyboardKey.backslash),
  ),
  ShortcutDefinition(
    action: ShortcutAction.navigateNext,
    label: 'Next item',
    description: 'Move down the list.',
    primaryDefault: const KeyboardShortcut(key: LogicalKeyboardKey.keyJ),
    secondaryDefault:
        const KeyboardShortcut(key: LogicalKeyboardKey.arrowDown),
  ),
  ShortcutDefinition(
    action: ShortcutAction.navigatePrev,
    label: 'Previous item',
    description: 'Move up the list.',
    primaryDefault: const KeyboardShortcut(key: LogicalKeyboardKey.keyK),
    secondaryDefault: const KeyboardShortcut(key: LogicalKeyboardKey.arrowUp),
  ),
  ShortcutDefinition(
    action: ShortcutAction.showShortcuts,
    label: 'Show shortcuts',
    description: 'Open the keyboard shortcut sheet.',
    primaryDefault: const KeyboardShortcut(
      key: LogicalKeyboardKey.slash,
      shift: true,
    ),
    secondaryDefault: _cmdOrCtrl(LogicalKeyboardKey.slash),
  ),
];

ShortcutDefinition definitionFor(ShortcutAction action) {
  return shortcutDefinitions.firstWhere((definition) => definition.action == action);
}
