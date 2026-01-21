import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/color_tokens.dart';
import '../../theme/glass.dart';
import '../../utils/fuzzy_match.dart';
import '../../widgets/glass/glass_text_field.dart';

class CommandPaletteItem {
  const CommandPaletteItem({
    required this.id,
    required this.title,
    required this.onSelected,
    required this.shortcutLabel,
    this.subtitle,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String shortcutLabel;
  final VoidCallback onSelected;
}

Future<void> showCommandPalette(
  BuildContext context, {
  required Color accent,
  required List<CommandPaletteItem> items,
}) async {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _CommandPaletteDialog(
      accent: accent,
      items: items,
    ),
  );
}

class _CommandPaletteDialog extends StatefulWidget {
  const _CommandPaletteDialog({
    required this.accent,
    required this.items,
  });

  final Color accent;
  final List<CommandPaletteItem> items;

  @override
  State<_CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<_CommandPaletteDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'CommandPaletteSearch');
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
    final filtered = widget.items
        .where(
          (item) => fuzzyMatch(
            _controller.text,
            '${item.title} ${item.subtitle ?? ''}',
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
              GlassTextField(
                controller: _controller,
                focusNode: _focusNode,
                hintText: 'Type a command…',
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
                  height: 280,
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final selected = index == _selectedIndex;
                      return InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                          item.onSelected();
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    if (item.subtitle != null)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 4),
                                        child: Text(
                                          item.subtitle!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: ColorTokens
                                                    .textSecondary(context),
                                              ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                item.shortcutLabel,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color:
                                          ColorTokens.textSecondary(context),
                                    ),
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
