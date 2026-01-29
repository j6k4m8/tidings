import 'package:flutter/material.dart';

import '../../../models/folder_models.dart';
import '../../../providers/email_provider.dart';
import '../../../state/tidings_settings.dart';
import '../../../theme/color_tokens.dart';
import '../../../theme/glass.dart';

class FolderList extends StatelessWidget {
  const FolderList({
    super.key,
    required this.accent,
    required this.provider,
    required this.sections,
    required this.selectedIndex,
    required this.onSelected,
  });

  final Color accent;
  final EmailProvider provider;
  final List<FolderSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final settings = context.tidingsSettings;
    final visibleSections = settings.showFolderLabels
        ? sections
        : sections
            .where((section) => section.kind != FolderSectionKind.labels)
            .toList();

    return ListView.builder(
      itemCount: visibleSections.length,
      itemBuilder: (context, sectionIndex) {
        final section = visibleSections[sectionIndex];
        return _FolderSection(
          section: section,
          accent: accent,
          isFolderLoading: provider.isFolderLoading,
          selectedIndex: selectedIndex,
          onSelected: onSelected,
        );
      },
    );
  }
}

Future<void> showFolderSheet(
  BuildContext context, {
  required Color accent,
  required EmailProvider provider,
  required List<FolderSection> sections,
  required int selectedFolderIndex,
  required ValueChanged<int> onFolderSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FolderSheet(
      accent: accent,
      provider: provider,
      sections: sections,
      selectedFolderIndex: selectedFolderIndex,
      onFolderSelected: onFolderSelected,
    ),
  );
}

class _FolderSheet extends StatelessWidget {
  const _FolderSheet({
    required this.accent,
    required this.provider,
    required this.sections,
    required this.selectedFolderIndex,
    required this.onFolderSelected,
  });

  final Color accent;
  final EmailProvider provider;
  final List<FolderSection> sections;
  final int selectedFolderIndex;
  final ValueChanged<int> onFolderSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(context.gutter(16)),
        child: GlassPanel(
          borderRadius: BorderRadius.circular(context.radius(24)),
          padding: EdgeInsets.all(context.space(16)),
          variant: GlassVariant.sheet,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Folders', style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: context.space(12)),
              Expanded(
                child: FolderList(
                  accent: accent,
                  provider: provider,
                  sections: sections,
                  selectedIndex: selectedFolderIndex,
                  onSelected: (index) {
                    onFolderSelected(index);
                    Navigator.of(context).pop();
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

class _FolderSection extends StatelessWidget {
  const _FolderSection({
    required this.section,
    required this.accent,
    required this.isFolderLoading,
    required this.selectedIndex,
    required this.onSelected,
  });

  final FolderSection section;
  final Color accent;
  final bool Function(String path) isFolderLoading;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.space(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: ColorTokens.textSecondary(context, 0.6),
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(height: context.space(8)),
          ...section.items.map((item) {
            return _FolderRow(
              item: item,
              accent: accent,
              isLoading: isFolderLoading(item.path),
              selected: item.index == selectedIndex,
              onTap: () => onSelected(item.index),
            );
          }),
        ],
      ),
    );
  }
}

class _FolderRow extends StatefulWidget {
  const _FolderRow({
    required this.item,
    required this.accent,
    required this.isLoading,
    required this.selected,
    required this.onTap,
  });

  final FolderItem item;
  final Color accent;
  final bool isLoading;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_FolderRow> createState() => _FolderRowState();
}

class _FolderRowState extends State<_FolderRow> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered == value) {
      return;
    }
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.tidingsSettings;
    final unread = widget.item.unreadCount > 0;
    final showUnreadCounts = settings.showFolderUnreadCounts;
    final isPinned = settings.isFolderPinned(widget.item.path);
    final showPin = _hovered || isPinned;
    final baseColor = Theme.of(context).colorScheme.onSurface;
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: unread ? baseColor : baseColor.withValues(alpha: 0.65),
      fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
    );

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          margin: EdgeInsets.only(bottom: context.space(4)),
          padding: EdgeInsets.fromLTRB(
            context.space(6) + widget.item.depth * context.space(12),
            context.space(4),
            context.space(6),
            context.space(4),
          ),
          decoration: BoxDecoration(
            color: widget.selected
                ? widget.accent.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(context.radius(12)),
          ),
          child: Row(
            children: [
              if (widget.selected)
                Container(
                  width: 2,
                  height: context.space(12),
                  margin: EdgeInsets.only(right: context.space(8)),
                  decoration: BoxDecoration(
                    color: widget.accent,
                    borderRadius: BorderRadius.circular(context.radius(8)),
                  ),
                )
              else
                SizedBox(width: context.space(8)),
              if (widget.item.icon != null) ...[
                Icon(
                  widget.item.icon,
                  size: 15,
                  color: unread
                      ? baseColor.withValues(alpha: 0.8)
                      : baseColor.withValues(alpha: 0.55),
                ),
                SizedBox(width: context.space(6)),
              ],
              Expanded(
                child: Text(
                  widget.item.name,
                  style: textStyle,
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  softWrap: true,
                ),
              ),
              if (widget.isLoading)
                Padding(
                  padding: EdgeInsets.only(right: context.space(6)),
                  child: SizedBox(
                    width: context.space(12),
                    height: context.space(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.accent.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              IgnorePointer(
                ignoring: !showPin,
                child: AnimatedOpacity(
                  opacity: showPin ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: IconButton(
                    onPressed: () =>
                        settings.toggleFolderPinned(widget.item.path),
                    icon: Icon(
                      isPinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      size: 14,
                    ),
                    color: isPinned
                        ? widget.accent
                        : ColorTokens.textSecondary(context, 0.7),
                    tooltip: isPinned ? 'Unpin from rail' : 'Pin to rail',
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints.tightFor(
                      width: context.space(24),
                      height: context.space(24),
                    ),
                  ),
                ),
              ),
              if (unread && showUnreadCounts)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.space(6),
                    vertical: context.space(1),
                  ),
                  decoration: BoxDecoration(
                    color: widget.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(context.radius(999)),
                  ),
                  child: Text(
                    widget.item.unreadCount.toString(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: widget.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
