import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/centered_content.dart';
import '../../../../shared/widgets/fade_slide_in.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../activity/presentation/widgets/feed_preview_section.dart';
import '../../../category/presentation/providers/category_providers.dart';
import '../../../category/presentation/widgets/category_card.dart';
import '../../../challenge/presentation/widgets/challenge_actions.dart';
import '../../../challenge/presentation/widgets/challenge_widgets.dart';
import '../../../leaderboard/presentation/providers/leaderboard_providers.dart';
import '../../../notifications/presentation/widgets/notifications_bell_button.dart';
import '../../../profile/domain/value_objects/username.dart';
import '../../../profile/presentation/providers/profile_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(currentUserProfileProvider).value;

    return Scaffold(
      body: SafeArea(
        child: CenteredContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (profile != null)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Hola, ${Username.display(profile.username)} \u{1F44B}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const NotificationsBellButton(),
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => context.go(AppRoutes.profile),
                      child: UserAvatar(avatar: profile.avatar, size: 40),
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.lg),
              const FadeSlideIn(child: _Hero()),
              const SizedBox(height: AppSpacing.lg),
              const FadeSlideIn(index: 1, child: ChallengeActions()),
              const SizedBox(height: AppSpacing.xl),
              FadeSlideIn(
                index: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(
                      title: 'Retos abiertos',
                      actionLabel: 'Crear',
                      onAction: () => context.push(AppRoutes.create),
                    ),
                    const OpenPublicChallengesList(limit: 5),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(
                index: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(
                      title: 'Retos activos',
                      actionLabel: 'Ver todos',
                      onAction: () => context.go(AppRoutes.challenges),
                    ),
                    const MyChallengesList(
                      onlyOpen: true,
                      limit: 3,
                      emptyTitle: 'Ningun reto en marcha',
                      emptyMessage: 'Crea uno o unete con un codigo.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const FadeSlideIn(
                index: 4,
                child: FeedPreviewSection(),
              ),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(
                index: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(
                      title: 'Categorias',
                      actionLabel: 'Ver todas',
                      onAction: () => context.push(AppRoutes.categories),
                    ),
                    const _CategoryCarousel(),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(
                index: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(title: 'Cerca de ti'),
                    EmptyStateView(
                      compact: true,
                      emoji: '\u{1F4CD}',
                      title: 'Explora locales cerca',
                      message: 'Abre Explorar para ver el mapa.',
                      actionLabel: 'Ir',
                      onAction: () => context.go(AppRoutes.explore),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(
                index: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(
                      title: 'Records y ranking',
                      actionLabel: 'Ver rankings',
                      onAction: () => context.go(AppRoutes.rankings),
                    ),
                    const _HomeRecordsPreview(),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const FadeSlideIn(index: 8, child: _ExploreTile()),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('\u{1F357} \u{1F363} \u{1F355} \u{1F32E} \u{1F369}',
            style: TextStyle(fontSize: 28)),
        const SizedBox(height: AppSpacing.md),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Que vas a '),
              TextSpan(
                text: 'comer',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
              const TextSpan(text: ' hoy?'),
            ],
          ),
          style: theme.textTheme.displaySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Convierte cualquier comida en un reto.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CategoryCarousel extends ConsumerWidget {
  const _CategoryCarousel();

  static const _height = 118.0;
  static const _itemWidth = 100.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    return switch (categories) {
      AsyncData(:final value) when value.isEmpty => const EmptyStateView(
        compact: true,
        emoji: '\u{1F37D}',
        title: 'Aun no hay categorias',
        message: 'El menu se esta preparando.',
      ),
      AsyncData(:final value) => SizedBox(
        height: _height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          // Todas las categorias (comida + bebidas); el carrusel hace scroll.
          itemCount: value.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) => SizedBox(
            width: _itemWidth,
            child: CategoryCard(category: value[i], compact: true),
          ),
        ),
      ),
      AsyncError() => ErrorStateView(
        compact: true,
        message: 'No pudimos cargar categorias.',
        onRetry: () => ref.invalidate(categoriesProvider),
      ),
      _ => const SizedBox(
        height: _height,
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _ExploreTile extends StatelessWidget {
  const _ExploreTile();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(AppRoutes.explore),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const Text('\u{1F5FA}', style: TextStyle(fontSize: 32)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Explorar',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Restaurantes y retos publicos',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeRecordsPreview extends ConsumerWidget {
  const _HomeRecordsPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(recentRecordsProvider);
    return records.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const EmptyStateView(
        compact: true,
        emoji: '\u{1F525}',
        title: 'Records oficiales',
        message: 'Cuando haya resultados apareceran aqui.',
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyStateView(
            compact: true,
            emoji: '\u{1F525}',
            title: 'Aun no hay records publicos',
            message: 'Finaliza un reto publico para materializar records.',
          );
        }
        return Column(
          children: [
            for (final r in items.take(3))
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('${r.score} · ${r.scopeKey}'),
                subtitle: Text(
                  r.holders.isEmpty
                      ? 'Sin titulares'
                      : r.holders.map((h) => h.displayName).join(', '),
                ),
              ),
          ],
        );
      },
    );
  }
}
