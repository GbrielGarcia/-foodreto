import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/establishment_status.dart';
import '../../domain/entities/restaurant.dart';
import '../providers/establishment_providers.dart';

class MyEstablishmentsPage extends ConsumerWidget {
  const MyEstablishmentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(myEstablishmentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mis locales')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.createEstablishment),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Registrar'),
      ),
      body: async.when(
        loading: () => const LoadingStateView(),
        error: (e, _) => ErrorStateView(
          message: 'No pudimos cargar tus locales.',
          onRetry: () => ref.invalidate(myEstablishmentsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyStateView(
              emoji: '\u{1F3EA}',
              title: 'Sin locales',
              message: 'Registra un establecimiento para retos y rankings.',
              actionLabel: 'Registrar local',
              onAction: () => context.push(AppRoutes.createEstablishment),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              88,
            ),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) {
              final r = list[i];
              return _EstablishmentCard(r: r, theme: theme);
            },
          );
        },
      ),
    );
  }
}

class _EstablishmentCard extends ConsumerWidget {
  const _EstablishmentCard({required this.r, required this.theme});

  final Restaurant r;
  final ThemeData theme;

  Color _statusColor(EstablishmentStatus s) => switch (s) {
        EstablishmentStatus.pending => theme.colorScheme.tertiaryContainer,
        EstablishmentStatus.approved => theme.colorScheme.secondaryContainer,
        EstablishmentStatus.rejected => theme.colorScheme.errorContainer,
        EstablishmentStatus.suspended => theme.colorScheme.surfaceContainerHighest,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserProvider)?.id;
    final canManage = uid != null && r.canOwnerManage(uid);
    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () => context.push(AppRoutes.restaurantPath(r.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.storefront_outlined,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          r.city.isEmpty ? 'Sin ciudad' : r.city,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(r.status),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      r.status.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        context.push(AppRoutes.restaurantPath(r.id)),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Ver ficha'),
                  ),
                  if (canManage) ...[
                    const SizedBox(width: 4),
                    FilledButton.tonalIcon(
                      onPressed: () => context.push(
                        AppRoutes.editEstablishmentPath(r.id),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Gestionar'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
