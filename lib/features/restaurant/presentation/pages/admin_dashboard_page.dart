import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/establishment_status.dart';
import '../providers/establishment_providers.dart';

/// Home del panel Super Admin.
class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pending = ref.watch(
      adminEstablishmentsProvider(EstablishmentStatus.pending),
    );
    final approved = ref.watch(
      adminEstablishmentsProvider(EstablishmentStatus.approved),
    );
    final suspended = ref.watch(
      adminEstablishmentsProvider(EstablishmentStatus.suspended),
    );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Administracion', style: theme.textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Panel exclusivo Super Admin. Gestion de establecimientos '
              'y operaciones de FoodReto.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                _StatCard(
                  label: 'Pendientes',
                  value: pending.when(
                    data: (l) => '${l.length}',
                    loading: () => '...',
                    error: (_, _) => '-',
                  ),
                  color: theme.colorScheme.tertiaryContainer,
                  onTap: () => context.go(AppRoutes.adminEstablishments),
                ),
                _StatCard(
                  label: 'Aprobados',
                  value: approved.when(
                    data: (l) => '${l.length}',
                    loading: () => '...',
                    error: (_, _) => '-',
                  ),
                  color: theme.colorScheme.secondaryContainer,
                  onTap: () => context.go(AppRoutes.adminEstablishments),
                ),
                _StatCard(
                  label: 'Suspendidos',
                  value: suspended.when(
                    data: (l) => '${l.length}',
                    loading: () => '...',
                    error: (_, _) => '-',
                  ),
                  color: theme.colorScheme.errorContainer,
                  onTap: () => context.go(AppRoutes.adminEstablishments),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(title: 'Acciones'),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('Solicitudes de establecimientos'),
              subtitle: const Text('Aprobar, rechazar, suspender, transferir'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(AppRoutes.adminEstablishments),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phone_android_outlined),
              title: const Text('Abrir app FoodReto'),
              subtitle: const Text(
                'Vista de usuario (retos, explorar, rankings)',
              ),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => context.go(AppRoutes.explore),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Las acciones criticas (aprobar / transferir) usan Cloud Functions '
              'cuando esten desplegadas. Mientras, la lista y revision usan '
              'Firestore Rules + claim/allowlist Super Admin.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: SizedBox(
          width: 140,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
