import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/color_tokens.dart';
import '../../theme/glass.dart';
import '../../utils/fuzzy_match.dart';
import '../../widgets/glass/glass_text_field.dart';

class GoToEntry {
  const GoToEntry({
    required this.title,
    required this.subtitle,
    required this.onSelected,
  });

  final String title;
  final String subtitle;
  final VoidCallback onSelected;
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
    final filtered = widget.entries
        .where(
          (entry) => fuzzyMatch(
            _controller.text,
            '${entry.title} ${entry.subtitle}',
          ),
        )
        .toList();
    if (_selectedIndex >= filtered.length) {
      _selectedIndex = 0;
    }
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
            final selected = filtered[_selectedIndex];
            Navigator.of(context).pop();
            selected.onSelected();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
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
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  Text(
                    '${filtered.length} folders',
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
              const SizedBox(height: 12),
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
                        onTap: () {
                          Navigator.of(context).pop();
                          entry.onSelected();
                        },
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
                                      entry.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        entry.subtitle,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: ColorTokens.textSecondary(
                                                context,
                                              ),
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_outward_rounded,
                                size: 16,
                                color: ColorTokens.textSecondary(context, 0.7),
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
    );
  }
}
