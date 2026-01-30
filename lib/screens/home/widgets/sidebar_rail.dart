import 'package:flutter/material.dart';

import '../../../models/account_models.dart';
import '../../../models/folder_models.dart';
import '../../../state/shortcut_definitions.dart';
import '../../../state/send_queue.dart';
import '../../../state/tidings_settings.dart';
import '../../../theme/glass.dart';
import '../../../widgets/account/account_avatar.dart';

const List<FolderItem> _fallbackRailItems = [
  FolderItem(
    index: 0,
    name: 'Inbox',
    path: 'Inbox',
    icon: Icons.inbox_rounded,
  ),
  FolderItem(
    index: -1,
    name: 'Outbox',
    path: kOutboxFolderPath,
    icon: Icons.outbox_rounded,
  ),
  FolderItem(
    index: 1,
    name: 'Archive',
    path: 'Archive',
    icon: Icons.archive_rounded,
  ),
  FolderItem(
    index: 2,
    name: 'Drafts',
    path: 'Drafts',
    icon: Icons.drafts_rounded,
  ),
  FolderItem(index: 3, name: 'Sent', path: 'Sent', icon: Icons.send_rounded),
];

class SidebarRail extends StatelessWidget {
  const SidebarRail({
    super.key,
    required this.account,
    required this.accent,
    required this.mailboxItems,
    required this.pinnedItems,
    required this.selectedIndex,
    required this.onSelected,
    required this.onExpand,
    required this.onAccountTap,
    required this.onCompose,
  });

  final EmailAccount account;
  final Color accent;
  final List<FolderItem> mailboxItems;
  final List<FolderItem> pinnedItems;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onExpand;
  final VoidCallback onAccountTap;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    final baseItems = mailboxItems.isEmpty ? _fallbackRailItems : mailboxItems;
    final items = <FolderItem>[];
    for (final item in baseItems) {
      items.add(item);
    }
    for (final item in pinnedItems) {
      if (items.any((existing) => existing.path == item.path)) {
        continue;
      }
      items.add(item);
    }
    return GlassPanel(
      borderRadius: BorderRadius.circular(context.radius(22)),
      padding: EdgeInsets.symmetric(
        vertical: context.space(12),
        horizontal: context.space(8),
      ),
      variant: GlassVariant.panel,
      child: Column(
        children: [
          AccountAvatar(
            name: account.displayName,
            accent: accent,
            onTap: onAccountTap,
          ),
          SizedBox(height: context.space(16)),
          for (final item in items.take(6))
            _RailIconButton(
              icon: item.icon ?? Icons.mail_outline_rounded,
              selected: selectedIndex == item.index,
              accent: accent,
              onTap: () => onSelected(item.index),
              label: item.name,
            ),
          const Spacer(),
          GlassPanel(
            borderRadius: BorderRadius.circular(context.radius(16)),
            padding: EdgeInsets.all(context.space(4)),
            variant: GlassVariant.pill,
            accent: accent,
            selected: true,
            child: IconButton(
              onPressed: onCompose,
              icon: const Icon(Icons.edit_rounded),
              tooltip:
                  'Compose (${context.tidingsSettings.shortcutLabel(ShortcutAction.compose, includeSecondary: false)})',
            ),
          ),
          IconButton(
            onPressed: onExpand,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Expand',
          ),
        ],
      ),
    );
  }
}

class _RailIconButton extends StatelessWidget {
  const _RailIconButton({
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
    required this.label,
  });

  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon),
      color: selected ? accent : Theme.of(context).colorScheme.onSurface,
      tooltip: label,
    );
  }
}
