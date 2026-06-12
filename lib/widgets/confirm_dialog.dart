import 'package:flutter/material.dart';

import '../state/tidings_settings.dart';
import '../theme/color_tokens.dart';
import '../theme/glass.dart';

/// Shows a glass confirmation dialog and resolves to `true` only if the user
/// taps the confirm button. Dismissing (tap outside / back) resolves to
/// `false`. Mirrors the destructive-confirm styling used elsewhere in the app.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  IconData confirmIcon = Icons.check_rounded,
  bool destructive = false,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final confirmColor = destructive ? Colors.redAccent : scheme.primary;
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: GlassPanel(
          borderRadius: BorderRadius.circular(context.radius(20)),
          padding: EdgeInsets.all(context.space(20)),
          variant: GlassVariant.sheet,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: context.space(8)),
              Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ColorTokens.textSecondary(context),
                ),
              ),
              SizedBox(height: context.space(20)),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: Text(cancelLabel),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    icon: Icon(confirmIcon),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: confirmColor,
                      side: BorderSide(
                        color: confirmColor.withValues(alpha: 0.5),
                      ),
                    ),
                    label: Text(confirmLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}
