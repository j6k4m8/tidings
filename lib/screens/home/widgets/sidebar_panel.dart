import 'package:flutter/material.dart';

import '../../../models/account_models.dart';
import '../../../models/folder_models.dart';
import '../../../providers/email_provider.dart';
import '../../../state/shortcut_definitions.dart';
import '../../../state/tidings_settings.dart';
import '../../../theme/color_tokens.dart';
import '../../../theme/glass.dart';
import '../../../widgets/account/account_avatar.dart';
import '../../../widgets/paper_panel.dart';
import 'folder_list.dart';

class SidebarPanel extends StatelessWidget {
  const SidebarPanel({
    super.key,
    required this.account,
    required this.accent,
    required this.provider,
    required this.sections,
    required this.selectedIndex,
    required this.onSelected,
    required this.onSettingsTap,
    required this.onCollapse,
    required this.onAccountTap,
    required this.onCompose,
    this.isUnified = false,
    this.accountCount = 0,
  });

  final EmailAccount account;
  final Color accent;
  final bool isUnified;
  final int accountCount;
  final EmailProvider provider;
  final List<FolderSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onSettingsTap;
  final VoidCallback onCollapse;
  final VoidCallback onAccountTap;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    return PaperPanel(
      borderRadius: BorderRadius.circular(context.radius(22)),
      padding: EdgeInsets.fromLTRB(
        context.space(14),
        context.space(16),
        context.space(14),
        context.space(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onAccountTap,
                  child: Row(
                    children: [
                      if (isUnified)
                        CircleAvatar(
                          radius: context.space(18),
                          backgroundColor: accent.withValues(alpha: 0.2),
                          child: Icon(
                            Icons.layers_rounded,
                            size: context.space(18),
                            color: accent,
                          ),
                        )
                      else
                        AccountAvatar(
                          name: account.displayName,
                          accent: accent,
                          showRing: true,
                        ),
                      SizedBox(width: context.space(10)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isUnified ? 'Unified Inbox' : account.displayName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              isUnified
                                  ? '$accountCount accounts'
                                  : account.email,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: ColorTokens.textSecondary(context),
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: onCollapse,
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Collapse',
              ),
            ],
          ),
          SizedBox(height: context.space(14)),
          Expanded(
            child: FolderList(
              accent: accent,
              provider: provider,
              sections: sections,
              selectedIndex: selectedIndex,
              onSelected: onSelected,
            ),
          ),
          SizedBox(height: context.space(8)),
          Row(
            children: [
              const Spacer(),
              GlassPanel(
                borderRadius: BorderRadius.circular(context.radius(18)),
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
            ],
          ),
        ],
      ),
    );
  }
}
