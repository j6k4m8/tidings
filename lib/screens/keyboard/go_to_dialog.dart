import 'package:flutter/material.dart';

import '../../theme/color_tokens.dart';
import '../../theme/glass.dart';
import '../../utils/fuzzy_match.dart';
import '../../widgets/glass/glass_text_field.dart';
import 'list_dialog_keys.dart';

class GoToEntry {
  const GoToEntry({
    required this.title,
    required this.subtitle,
    required this.onSelected,
    required this.accentColor,
    this.isPriority = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback onSelected;
  /// Per-account accent dot shown in each row.
  final Color accentColor;
  /// Priority entries are sorted to the top (e.g. current account's folders).
  final bool isPriority;
}

Future<void> showGoToDialog(
  BuildContext context, {
  required Color accent,
  required List<GoToEntry> entries,
  required String title,
}) async {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _GoToDialog(
      accent: accent,
      entries: entries,
      title: title,
    ),
  );
}

class _GoToDialog extends StatefulWidget {
  const _GoToDialog({
    required this.accent,
    required this.entries,
    required this.title,
  });

  final Color accent;
  final List<GoToEntry> entries;
  final String title;

  @override
  State<_GoToDialog> createState() => _GoToDialogState();
}

class _GoToDialogState extends State<_GoToDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'GoToSearch');
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = widget.entries
        .where(
          (entry) => fuzzyMatch(
            _controller.text,
            '${entry.title} ${entry.subtitle}',
          ),
        )
        .toList()
      // Stable sort: priority (current account) entries first.
      ..sort((a, b) {
        if (a.isPriority == b.isPriority) return 0;
        return a.isPriority ? -1 : 1;
      });
    if (_selectedIndex >= filtered.length) {
      _selectedIndex = 0;
    }
    final n = filtered.length;
    final countLabel = n == 1 ? '·  1 result' : '·  $n results';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      alignment: Alignment.topCenter,
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) => handleListDialogKey(
          event: event,
          listLength: filtered.length,
          onMove: (d) => _moveSelection(d, filtered.length),
          onEnter: () {
            if (filtered.isEmpty) return;
            final selected = filtered[_selectedIndex];
            Navigator.of(context).pop();
            selected.onSelected();
          },
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
                // ── Header ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Row(
                    children: [
                      Text(
                        widget.title,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        countLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: ColorTokens.textSecondary(context),
                            ),
                      ),
                    ],
                  ),
                ),

                // ── Search ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: GlassTextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    hintText: 'Search…',
                    onChanged: (_) => setState(() {}),
                  ),
                ),

                const SizedBox(height: 8),

                // ── Divider ───────────────────────────────────────────────
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.07),
                ),

                // ── List ──────────────────────────────────────────────────
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No matches',
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
                        final showSubtitle = entry.subtitle.isNotEmpty &&
                            entry.subtitle != entry.title;
                        return InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                            entry.onSelected();
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              // Use the entry's own accent so the highlight
                              // color always matches the account dot, regardless
                              // of which account's accent is currently active.
                              color: selected
                                  ? entry.accentColor.withValues(alpha: 0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: entry.accentColor,
                                    boxShadow: selected
                                        ? [
                                            BoxShadow(
                                              color: entry.accentColor
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 4,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: showSubtitle
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              entry.title,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium,
                                            ),
                                            Text(
                                              entry.subtitle,
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
                                          entry.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                        ),
                                ),
                                if (selected)
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 14,
                                    color: entry.accentColor.withValues(alpha: 0.7),
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
