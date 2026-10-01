import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../shared/widgets/state_views.dart';
import '../providers/activity_providers.dart';
import 'activity_tile.dart';

/// Vista previa del feed para Home.
class FeedPreviewSection extends ConsumerWidget {
  const FeedPreviewSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(feedPreviewProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Actividad',
          actionLabel: 'Ver todo',
          onAction: () => context.push(AppRoutes.feed),
        ),
        preview.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => EmptyStateView(
            compact: true,
            emoji: '\u26a0\ufe0f',
            title: 'No se pudo cargar',
            message: 'Int\u00e9ntalo m\u00e1s tarde.',
            actionLabel: 'Reintentar',
            onAction: () => ref.invalidate(feedPreviewProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return EmptyStateView(
                compact: true,
                emoji: '\u{1F4E1}',
                title: 'No hay actividad todav\u00eda.',
                message: 'Agrega amigos y empieza a competir.',
                actionLabel: 'Buscar amigos',
                onAction: () => context.push(AppRoutes.userSearch),
              );
            }
            return Column(
              children: [
                for (final a in items) ActivityTile(activity: a),
              ],
            );
          },
        ),
      ],
    );
  }
}
