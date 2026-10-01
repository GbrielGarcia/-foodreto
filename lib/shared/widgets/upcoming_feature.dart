import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import 'centered_content.dart';

/// Estado vacío para secciones cuya funcionalidad llega en una fase posterior.
class UpcomingFeature extends StatelessWidget {
  const UpcomingFeature({
    super.key,
    required this.emoji,
    required this.title,
    required this.description,
  });

  final String emoji;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: CenteredContent(
        maxWidth: 420,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xxl),
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
