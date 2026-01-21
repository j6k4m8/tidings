import 'package:flutter/material.dart';

import '../../state/shortcut_definitions.dart';
import '../../state/tidings_settings.dart';
import '../../theme/color_tokens.dart';
import '../../theme/glass.dart';

Future<void> showShortcutsSheet(BuildContext context) async {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => const _ShortcutsSheet(),
  );
}

class _ShortcutsSheet extends StatelessWidget {
  const _ShortcutsSheet();

  @override
  Widget build(BuildContext context) {
    final settings = context.tidingsSettings;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: GlassPanel(
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.all(16),
        variant: GlassVariant.sheet,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'Keyboard shortcuts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumn = constraints.maxWidth >= 560;
                final rowExtent = twoColumn ? 64.0 : 60.0;
                return GridView.builder(
                  itemCount: shortcutDefinitions.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: twoColumn ? 2 : 1,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    mainAxisExtent: rowExtent,
                  ),
                  itemBuilder: (context, index) {
                    final definition = shortcutDefinitions[index];
                    final primary = settings.shortcutFor(definition.action);
                    final secondary =
                        settings.secondaryShortcutFor(definition.action);
                    return _ShortcutCard(
                      label: definition.label,
                      description: definition.description,
                      primary: primary.label(),
                      secondary: secondary?.label(),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.label,
    required this.description,
    required this.primary,
    this.secondary,
  });

  final String label;
  final String description;
  final String primary;
  final String? secondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ColorTokens.cardFill(context, 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorTokens.border(context, 0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ColorTokens.textSecondary(context),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _KbdRow(label: primary),
              if (secondary != null) ...[
                const SizedBox(height: 6),
                _KbdRow(label: secondary!, muted: true),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _KbdRow extends StatelessWidget {
  const _KbdRow({
    required this.label,
    this.muted = false,
  });

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final parts = label.split(' + ');
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: muted
              ? ColorTokens.textSecondary(context, 0.7)
              : ColorTokens.textPrimary(context),
          fontWeight: FontWeight.w600,
        );
    final widgets = <Widget>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) {
        widgets.add(Text('+', style: textStyle));
      }
      widgets.add(_KbdKey(label: parts[i], muted: muted));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: widgets,
    );
  }
}

class _KbdKey extends StatelessWidget {
  const _KbdKey({
    required this.label,
    this.muted = false,
  });

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final border = ColorTokens.border(context, muted ? 0.12 : 0.18);
    final fill = ColorTokens.cardFill(context, muted ? 0.08 : 0.16);
    final textColor = muted
        ? ColorTokens.textSecondary(context, 0.7)
        : ColorTokens.textPrimary(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
      ),
    );
  }
}
