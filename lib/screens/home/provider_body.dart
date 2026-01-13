import 'package:flutter/material.dart';

import '../../providers/email_provider.dart';
import '../../theme/color_tokens.dart';

class ProviderBody extends StatelessWidget {
  const ProviderBody({
    super.key,
    required this.status,
    required this.errorMessage,
    required this.onRetry,
    required this.isEmpty,
    required this.emptyMessage,
    required this.child,
  });

  final ProviderStatus status;
  final String? errorMessage;
  final VoidCallback onRetry;
  final bool isEmpty;
  final String emptyMessage;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (status == ProviderStatus.loading || status == ProviderStatus.idle) {
      return const Center(child: CircularProgressIndicator());
    }
    if (status == ProviderStatus.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              errorMessage ?? 'Unable to load mail.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ColorTokens.textSecondary(context),
              ),
        ),
      );
    }
    return child;
  }
}
