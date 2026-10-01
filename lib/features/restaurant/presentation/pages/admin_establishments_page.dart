import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/establishment_status.dart';
import '../../domain/entities/restaurant.dart';
import '../providers/establishment_providers.dart';

class AdminEstablishmentsPage extends ConsumerStatefulWidget {
  const AdminEstablishmentsPage({super.key});

  @override
  ConsumerState<AdminEstablishmentsPage> createState() =>
      _AdminEstablishmentsPageState();
}

class _AdminEstablishmentsPageState
    extends ConsumerState<AdminEstablishmentsPage> {
  EstablishmentStatus _filter = EstablishmentStatus.pending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(adminEstablishmentsProvider(_filter));
    return Scaffold(
      appBar: AppBar(title: const Text('Locales')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in EstablishmentStatus.values)
                  FilterChip(
                    label: Text(s.label),
                    selected: _filter == s,
                    onSelected: (_) => setState(() => _filter = s),
                  ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const LoadingStateView(),
              error: (e, _) => ErrorStateView(
                message: 'Error al listar.',
                onRetry: () =>
                    ref.invalidate(adminEstablishmentsProvider(_filter)),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return EmptyStateView(
                    emoji: '\u2705',
                    title: 'Nada en ${_filter.label}',
                    message: 'Cambia el filtro o espera solicitudes.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: list.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) => _AdminCard(r: list[i], theme: theme),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({required this.r, required this.theme});

  final Restaurant r;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () => context.push(AppRoutes.adminEstablishmentPath(r.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
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
                    const SizedBox(height: 4),
                    Text(
                      '${r.city} · ${r.status.label}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
