import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/state_views.dart';
import '../providers/notification_providers.dart';
import '../widgets/notification_tile.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final feed = ref.watch(notificationsControllerProvider);
    final unread = ref.watch(unreadNotificationCountProvider).value ?? 0;
    final canPop = context.canPop();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Notificaciones'),
        leading: canPop
            ? IconButton(
                tooltip: 'Volver',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : IconButton(
                tooltip: 'Volver',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/'),
              ),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () => ref
                  .read(notificationsControllerProvider.notifier)
                  .markAllRead(),
              child: const Text('Marcar todas'),
            ),
        ],
      ),
      // Sin Column/Expanded: evita pantalla negra si el padre da altura
      // infinita (p. ej. scroll anidado).
      body: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyStateView(
          emoji: '\u26a0\ufe0f',
          title: 'No se pudo cargar',
          message: e.toString(),
          actionLabel: 'Intentar nuevamente',
          onAction: () =>
              ref.read(notificationsControllerProvider.notifier).refresh(),
        ),
        data: (state) {
          if (state.items.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(
                  'Todas al dia',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const EmptyStateView(
                  compact: true,
                  emoji: '\u{1F514}',
                  title: 'Sin notificaciones',
                  message:
                      'Te avisaremos de retos, amigos y records aqui.',
                ),
              ],
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(notificationsControllerProvider.notifier).refresh(),
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200 &&
                    state.hasMore &&
                    !state.loadingMore) {
                  ref
                      .read(notificationsControllerProvider.notifier)
                      .loadMore();
                }
                return false;
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: state.items.length + 2,
                separatorBuilder: (_, i) {
                  if (i == 0) return const SizedBox(height: AppSpacing.md);
                  return const Divider(height: 1);
                },
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Text(
                      unread > 0 ? '$unread sin leer' : 'Todas al dia',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    );
                  }
                  final index = i - 1;
                  if (index < state.items.length) {
                    return NotificationTile(
                      notification: state.items[index],
                    );
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
                      'No hay mas notificaciones.',
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
