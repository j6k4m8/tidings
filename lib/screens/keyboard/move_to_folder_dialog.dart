import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/folder_models.dart';
import '../../state/send_queue.dart';
import '../../theme/color_tokens.dart';
import '../../theme/glass.dart';
import '../../utils/fuzzy_match.dart';
import '../../widgets/accent_switch.dart';
import '../../widgets/glass/glass_text_field.dart';

class MoveToFolderResult {
  const MoveToFolderResult({
    required this.folderPath,
    required this.moveEntireThread,
  });

  final String folderPath;
  final bool moveEntireThread;
}

/// Flat folder entry for the picker — built from [FolderSection] lists by
/// callers, with [currentFolderPath] already excluded.
class MoveToFolderEntry {
  const MoveToFolderEntry({
    required this.path,
    required this.displayName,
  });

  final String path;
  final String displayName;
}

Future<MoveToFolderResult?> showMoveToFolderDialog(
  BuildContext context, {
  required Color accent,
  required List<MoveToFolderEntry> entries,
  required int messageCount,
  required bool defaultMoveEntireThread,
}) {
  return showDialog<MoveToFolderResult>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _MoveToFolderDialog(
      accent: accent,
      entries: entries,
      messageCount: messageCount,
      defaultMoveEntireThread: defaultMoveEntireThread,
    ),
  );
}

class _MoveToFolderDialog extends StatefulWidget {
  const _MoveToFolderDialog({
    required this.accent,
    required this.entries,
    required this.messageCount,
    required this.defaultMoveEntireThread,
  });

  final Color accent;
  final List<MoveToFolderEntry> entries;
  final int messageCount;
  final bool defaultMoveEntireThread;

  @override
  State<_MoveToFolderDialog> createState() => _MoveToFolderDialogState();
}

class _MoveToFolderDialogState extends State<_MoveToFolderDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'MoveToFolderSearch');
  int _selectedIndex = 0;
  late bool _moveEntireThread;

  @override
  void initState() {
    super.initState();
    _moveEntireThread = widget.defaultMoveEntireThread;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _moveSelection(int delta, int max) {
    if (max <= 0) {
      return;
    }
    setState(() {
      _selectedIndex = (_selectedIndex + delta).clamp(0, max - 1);
    });
  }

  void _confirm(MoveToFolderEntry entry) {
    Navigator.of(context).pop(
      MoveToFolderResult(
        folderPath: entry.path,
        moveEntireThread: _moveEntireThread,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.entries
        .where(
          (entry) => fuzzyMatch(
            _controller.text,
            '${entry.displayName} ${entry.path}',
          ),
        )
        .toList();
    if (_selectedIndex >= filtered.length) {
      _selectedIndex = 0;
    }
    final threadLabel = widget.messageCount == 1
        ? 'Move entire thread (1 message)'
        : 'Move entire thread (${widget.messageCount} messages)';
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) {
            return KeyEventResult.ignored;
          }
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).maybePop();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _moveSelection(1, filtered.length);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _moveSelection(-1, filtered.length);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter &&
              filtered.isNotEmpty) {
            _confirm(filtered[_selectedIndex]);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: GlassPanel(
            borderRadius: BorderRadius.circular(20),
            padding: const EdgeInsets.all(16),
            variant: GlassVariant.sheet,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Move to folder',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Text(
                      '${filtered.length} folder${filtered.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: ColorTokens.textSecondary(context),
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GlassTextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  hintText: 'Search folders…',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        threadLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: ColorTokens.textSecondary(context),
                            ),
                      ),
                    ),
                    AccentSwitch(
                      accent: widget.accent,
                      value: _moveEntireThread,
                      onChanged: (value) {
                        setState(() => _moveEntireThread = value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No matches',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: ColorTokens.textSecondary(context),
                          ),
                    ),
                  )
                else
                  SizedBox(
                    height: 320,
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final entry = filtered[index];
                        final selected = index == _selectedIndex;
                        return InkWell(
                          onTap: () => _confirm(entry),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? widget.accent.withValues(alpha: 0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? widget.accent.withValues(alpha: 0.25)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.displayName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 4),
                                        child: Text(
                                          entry.path,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color:
                                                    ColorTokens.textSecondary(
                                                  context,
                                                ),
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.drive_file_move_outlined,
                                  size: 16,
                                  color:
                                      ColorTokens.textSecondary(context, 0.7),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Builds a flat list of [MoveToFolderEntry] from [FolderSection] lists,
/// excluding [currentFolderPath] and [kOutboxFolderPath].
List<MoveToFolderEntry> buildMoveToFolderEntries(
  List<FolderSection> sections, {
  required String currentFolderPath,
}) {
  final entries = <MoveToFolderEntry>[];
  for (final section in sections) {
    for (final item in section.items) {
      if (item.path == currentFolderPath) {
        continue;
      }
      if (item.path == kOutboxFolderPath) {
        continue;
      }
      entries.add(
        MoveToFolderEntry(
          path: item.path,
          displayName: item.name,
        ),
      );
    }
  }
  return entries;
}
