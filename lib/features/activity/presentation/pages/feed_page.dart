import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/state_views.dart';
import '../providers/activity_providers.dart';
import '../widgets/activity_tile.dart';

/// Feed completo de actividad social.
class FeedPage extends ConsumerWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final feed = ref.watch(feedControllerProvider);
    final canPop = context.canPop();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Actividad'),
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (canPop) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
      ),
      body: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyStateView(
          emoji: '\u26a0\ufe0f',
          title: 'No se pudo cargar',
          message: e.toString(),
          actionLabel: 'Intentar nuevamente',
          onAction: () => ref.read(feedControllerProvider.notifier).refresh(),
        ),
        data: (state) {
          if (state.items.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(
                  'Retos, victorias y records de tu circulo.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                EmptyStateView(
                  compact: true,
                  emoji: '\u{1F4E1}',
                  title: 'No hay actividad todavia.',
                  message: 'Agrega amigos y empieza a competir.',
                  actionLabel: 'Buscar amigos',
                  onAction: () => context.push(AppRoutes.userSearch),
                ),
              ],
            );
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(feedControllerProvider.notifier).refresh(),
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200 &&
                    state.hasMore &&
                    !state.loadingMore) {
                  ref.read(feedControllerProvider.notifier).loadMore();
                }
                return false;
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: state.items.length + 1,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  if (i < state.items.length) {
                    return ActivityTile(activity: state.items[i]);
                  }
                  if (state.hasMore) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(
                        child: SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'No hay mas actividad.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
