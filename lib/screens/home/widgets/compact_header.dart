import 'package:flutter/material.dart';

import '../../../models/account_models.dart';
import '../../../models/folder_models.dart';
import '../../../providers/email_provider.dart';
import '../../../state/tidings_settings.dart';
import '../../../theme/glass.dart';
import '../../../widgets/account/account_avatar.dart';
import 'folder_list.dart';

class CompactHeader extends StatelessWidget {
  const CompactHeader({
    super.key,
    required this.account,
    required this.accent,
    required this.provider,
    required this.sections,
    required this.selectedFolderIndex,
    required this.onFolderSelected,
    required this.onAccountTap,
  });

  final EmailAccount account;
  final Color accent;
  final EmailProvider provider;
  final List<FolderSection> sections;
  final int selectedFolderIndex;
  final ValueChanged<int> onFolderSelected;
  final VoidCallback onAccountTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GlassPanel(
          borderRadius: BorderRadius.circular(context.radius(18)),
          padding: EdgeInsets.all(context.space(6)),
          variant: GlassVariant.pill,
          child: AccountAvatar(name: account.displayName, accent: accent),
        ),
        SizedBox(width: context.space(12)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              account.displayName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              account.email,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const Spacer(),
        IconButton(
          onPressed: onAccountTap,
          icon: const Icon(Icons.people_alt_rounded),
          tooltip: 'Accounts',
        ),
        IconButton(
          onPressed: () => showFolderSheet(
            context,
            accent: accent,
            provider: provider,
            sections: sections,
            selectedFolderIndex: selectedFolderIndex,
            onFolderSelected: onFolderSelected,
          ),
          icon: const Icon(Icons.folder_open_rounded),
          tooltip: 'Folders',
        ),
      ],
    );
  }
}
