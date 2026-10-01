import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_labels.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../category/domain/entities/food_category.dart';
import '../../../category/presentation/providers/category_providers.dart';
import '../../../restaurant/presentation/providers/restaurant_providers.dart';
import '../../domain/entities/challenge.dart';
import '../providers/challenge_providers.dart';

/// Categoría del reto (del catálogo en memoria, sin lecturas extra).
FoodCategory? watchChallengeCategory(WidgetRef ref, String categoryId) =>
    ref.watch(categoryByIdProvider(categoryId)).value;

/// Nombre del restaurante o `null` si el reto no tiene / no se pudo leer.
String? watchRestaurantName(WidgetRef ref, String? restaurantId) {
  if (restaurantId == null) return null;
  return ref.watch(restaurantProvider(restaurantId)).value?.name;
}

/// "🍗 Reto de alitas · 📍 Wing House".
class ChallengeHeader extends ConsumerWidget {
  const ChallengeHeader({
    super.key,
    required this.challenge,
    this.large = false,
  });

  final Challenge challenge;
  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final category = watchChallengeCategory(ref, challenge.categoryId);
    final restaurant = watchRestaurantName(ref, challenge.restaurantId);
    final title = challenge.displayTitle(category?.name);

    return Row(
      children: [
        Text(
          category?.icon ?? '🍽️',
          style: TextStyle(fontSize: large ? 44 : 32),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    (large
                            ? theme.textTheme.headlineSmall
                            : theme.textTheme.titleLarge)
                        ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (category != null)
                    'Se cuenta en ${category.defaultUnit.plural}',
                  if (restaurant != null) '📍 $restaurant',
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ChallengeStatusChip extends StatelessWidget {
  const ChallengeStatusChip({super.key, required this.status});

  final ChallengeStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, fg, bg) = switch (status) {
      ChallengeStatus.draft => (
        'Borrador',
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHighest,
      ),
      ChallengeStatus.waiting => (
        'Esperando',
        scheme.onSecondaryContainer,
        scheme.secondaryContainer,
      ),
      ChallengeStatus.active => (
        'En curso',
        scheme.onTertiaryContainer,
        scheme.tertiaryContainer,
      ),
      ChallengeStatus.finished => (
        'Terminado',
        scheme.onPrimaryContainer,
        scheme.primaryContainer,
      ),
      ChallengeStatus.cancelled => (
        'Cancelado',
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHigh,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Fila del historial: comida, título, estado y participantes.
class ChallengeListTile extends ConsumerWidget {
  const ChallengeListTile({super.key, required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final category = watchChallengeCategory(ref, challenge.categoryId);
    final date =
        challenge.finishedAt ?? challenge.startedAt ?? challenge.createdAt;
    final subtitle = [
      '${challenge.participantIds.length} '
          '${challenge.participantIds.length == 1 ? 'participante' : 'participantes'}',
      if (date != null) DateLabels.dayMonthYear(date),
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.challengePath(challenge.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Text(
                category?.icon ?? '🍽️',
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.displayTitle(category?.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ChallengeStatusChip(status: challenge.status),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lista de mis retos con su estado vacío. [onlyOpen] muestra solo los que
/// esperan o están en curso (inicio); [limit] recorta la lista (perfil).
class MyChallengesList extends ConsumerWidget {
  const MyChallengesList({
    super.key,
    this.onlyOpen = false,
    this.limit,
    this.emptyTitle = 'Todavía no tienes retos',
    this.emptyMessage = 'Tu próximo récord puede empezar aquí.',
  });

  final bool onlyOpen;
  final int? limit;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenges = ref.watch(myChallengesProvider);
    return switch (challenges) {
      AsyncData(:final value) => () {
        var list = onlyOpen
            ? value.where((c) => !c.status.isClosed).toList()
            : value;
        if (limit != null && list.length > limit!) {
          list = list.take(limit!).toList();
        }
        if (list.isEmpty) {
          return EmptyStateView(
            compact: true,
            emoji: '🏁',
            title: emptyTitle,
            message: emptyMessage,
            actionLabel: 'Crear',
            onAction: () => context.push(AppRoutes.create),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final c in list) ChallengeListTile(challenge: c)],
        );
      }(),
      AsyncError() => ErrorStateView(
        compact: true,
        message: 'No pudimos cargar tus retos.',
        onRetry: () => ref.invalidate(myChallengesProvider),
      ),
      _ => const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

/// Retos publicos abiertos (para amigos / descubrir en Home).
class OpenPublicChallengesList extends ConsumerWidget {
  const OpenPublicChallengesList({super.key, this.limit = 5});

  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final async = ref.watch(openPublicChallengesProvider);
    return switch (async) {
      AsyncData(:final value) => () {
        final list = [
          for (final c in value)
            if (uid == null || !c.isParticipant(uid)) c,
        ].take(limit).toList();
        if (list.isEmpty) {
          return EmptyStateView(
            compact: true,
            emoji: '📣',
            title: 'Sin retos publicos abiertos',
            message: 'Cuando un amigo cree uno, saldra aqui.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final c in list) ChallengeListTile(challenge: c),
          ],
        );
      }(),
      AsyncError() => ErrorStateView(
        compact: true,
        message: 'No pudimos cargar retos publicos.',
        onRetry: () => ref.invalidate(openPublicChallengesProvider),
      ),
      _ => const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}
