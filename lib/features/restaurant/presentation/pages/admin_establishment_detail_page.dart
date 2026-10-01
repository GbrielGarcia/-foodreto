import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/establishment_status.dart';
import '../providers/establishment_providers.dart';

class AdminEstablishmentDetailPage extends ConsumerStatefulWidget {
  const AdminEstablishmentDetailPage({super.key, required this.establishmentId});

  final String establishmentId;

  @override
  ConsumerState<AdminEstablishmentDetailPage> createState() =>
      _AdminEstablishmentDetailPageState();
}

class _AdminEstablishmentDetailPageState
    extends ConsumerState<AdminEstablishmentDetailPage> {
  final _reason = TextEditingController();
  final _newOwner = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    _newOwner.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(establishmentDetailProvider(widget.establishmentId));
      for (final s in EstablishmentStatus.values) {
        ref.invalidate(adminEstablishmentsProvider(s));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listo')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async =
        ref.watch(establishmentDetailProvider(widget.establishmentId));
    final svc = ref.watch(establishmentAdminServiceProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Revision'),
        actions: [
          IconButton(
            tooltip: 'Ver ficha publica',
            onPressed: () => context.push(
              AppRoutes.restaurantPath(widget.establishmentId),
            ),
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingStateView(),
        error: (e, _) => ErrorStateView(
          message: 'No se pudo cargar.',
          onRetry: () => ref.invalidate(
            establishmentDetailProvider(widget.establishmentId),
          ),
        ),
        data: (r) {
          if (r == null) {
            return const EmptyStateView(
              emoji: '\u2753',
              title: 'No encontrado',
              message: 'Sin acceso o ID invalido.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                r.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.flag_outlined, size: 16),
                    label: Text(r.status.label),
                  ),
                  Chip(
                    avatar: const Icon(Icons.place_outlined, size: 16),
                    label: Text(r.city.isEmpty ? 'Sin ciudad' : r.city),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Creator: ${r.creatorUserId ?? "-"}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                'Owner: ${r.ownerUserId ?? "-"}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Acciones', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(
                              () => svc.approve(widget.establishmentId),
                            ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Aprobar'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(
                              () => svc.reject(
                                widget.establishmentId,
                                reason: _reason.text,
                              ),
                            ),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Rechazar'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(
                              () => svc.suspend(
                                widget.establishmentId,
                                reason: _reason.text,
                              ),
                            ),
                    icon: const Icon(Icons.pause_circle_outline),
                    label: const Text('Suspender'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(
                              () => svc.reactivate(widget.establishmentId),
                            ),
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Reactivar'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _reason,
                decoration: const InputDecoration(
                  labelText: 'Motivo (rechazo / suspension)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Transferir ownership', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _newOwner,
                decoration: const InputDecoration(
                  labelText: 'Nuevo owner UID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.tonal(
                onPressed: _busy
                    ? null
                    : () => _run(
                          () => svc.transferOwnership(
                            widget.establishmentId,
                            newOwnerUserId: _newOwner.text.trim(),
                          ),
                        ),
                child: const Text('Transferir'),
              ),
            ],
          );
        },
      ),
    );
  }
}
