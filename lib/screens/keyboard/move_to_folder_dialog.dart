import 'package:flutter/material.dart';

import '../../models/folder_models.dart';
import '../../state/send_queue.dart';
import '../../theme/color_tokens.dart';
import '../../theme/glass.dart';
import '../../utils/fuzzy_match.dart';
import '../../widgets/accent_switch.dart';
import '../../widgets/glass/glass_text_field.dart';
import 'list_dialog_keys.dart';

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
  // Hide the "move entire thread" toggle when acting from the folder-level
  // shortcut (always moves whole thread) or when the thread has only one
  // message (toggle would be meaningless).
  bool showThreadToggle = true,
}) {
  return showDialog<MoveToFolderResult>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _MoveToFolderDialog(
      accent: accent,
      entries: entries,
      messageCount: messageCount,
      defaultMoveEntireThread: defaultMoveEntireThread,
      showThreadToggle: showThreadToggle,
    ),
  );
}

class _MoveToFolderDialog extends StatefulWidget {
  const _MoveToFolderDialog({
    required this.accent,
    required this.entries,
    required this.messageCount,
    required this.defaultMoveEntireThread,
    required this.showThreadToggle,
  });

  final Color accent;
  final List<MoveToFolderEntry> entries;
  final int messageCount;
  final bool defaultMoveEntireThread;
  final bool showThreadToggle;

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
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _moveSelection(int delta, int max) {
    if (max <= 0) return;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) => handleListDialogKey(
          event: event,
          listLength: filtered.length,
          onMove: (d) => _moveSelection(d, filtered.length),
          onEnter: () => _confirm(filtered[_selectedIndex]),
          context: context,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: GlassPanel(
            borderRadius: BorderRadius.circular(20),
            padding: EdgeInsets.zero,
            variant: GlassVariant.sheet,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Row(
                    children: [
                      Text(
                        'Move to folder',
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '·  ${filtered.length}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: ColorTokens.textSecondary(context),
                            ),
                      ),
                    ],
                  ),
                ),

                // ── Search ──────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: GlassTextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    hintText: 'Search folders…',
                    onChanged: (_) => setState(() {}),
                  ),
                ),

                // ── Thread toggle (conditional) ──────────────────────────
                if (widget.showThreadToggle) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 10, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.messageCount == 1
                                ? 'Move entire thread'
                                : 'Move entire thread  (${widget.messageCount} messages)',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: ColorTokens.textSecondary(context),
                                    ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AccentSwitch(
                          accent: widget.accent,
                          value: _moveEntireThread,
                          onChanged: (v) =>
                              setState(() => _moveEntireThread = v),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                // ── Divider ──────────────────────────────────────────────────
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.07),
                ),

                // ── Folder list ──────────────────────────────────────────────
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No folders match',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: ColorTokens.textSecondary(context),
                            ),
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 340),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final entry = filtered[index];
                        final selected = index == _selectedIndex;
                        // Only show the path subtitle when it differs from
                        // the display name (avoids redundant "Drafts / Drafts").
                        final showPath = entry.path != entry.displayName;
                        return InkWell(
                          onTap: () => _confirm(entry),
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? widget.accent.withValues(alpha: 0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.folder_outlined,
                                  size: 15,
                                  color: selected
                                      ? widget.accent
                                      : ColorTokens.textSecondary(
                                          context,
                                          0.5,
                                        ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: showPath
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              entry.displayName,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium,
                                            ),
                                            Text(
                                              entry.path,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color:
                                                        ColorTokens.textSecondary(
                                                      context,
                                                      0.5,
                                                    ),
                                                  ),
                                            ),
                                          ],
                                        )
                                      : Text(
                                          entry.displayName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                        ),
                                ),
                                if (selected)
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 14,
                                    color:
                                        widget.accent.withValues(alpha: 0.7),
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
      if (item.path == currentFolderPath) continue;
      if (item.path == kOutboxFolderPath) continue;
      entries.add(
        MoveToFolderEntry(path: item.path, displayName: item.name),
      );
    }
  }
  return entries;
}
