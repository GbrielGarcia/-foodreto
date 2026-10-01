import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_labels.dart';
import '../../../../shared/widgets/centered_content.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../challenge/presentation/widgets/challenge_widgets.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/user_statistics.dart';
import '../../domain/value_objects/username.dart';
import '../providers/profile_providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(
            tooltip: 'Editar perfil',
            onPressed: () => context.push(AppRoutes.editProfile),
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            onSelected: (value) {
              if (value == 'logout') {
                ref.read(authControllerProvider.notifier).signOut();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout_rounded),
                  title: Text('Cerrar sesión'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: switch (profile) {
        AsyncData(value: final UserProfile p) => _ProfileContent(profile: p),
        AsyncError() => ErrorStateView(
          message: 'No pudimos cargar tu perfil.',
          onRetry: () => ref.invalidate(currentUserProfileProvider),
        ),
        _ => const LoadingStateView(),
      },
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(userStatisticsProvider);

    return CenteredContent(
      maxWidth: 1040,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final header = _ProfileHeader(profile: profile, stats: stats);
          const sections = _ProfileSections();
          if (constraints.maxWidth < 840) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: AppSpacing.xl),
                sections,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 360, child: header),
              const SizedBox(width: AppSpacing.xl),
              const Expanded(child: sections),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile, required this.stats});

  final UserProfile profile;
  final AsyncValue<UserStatistics> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final values = stats.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: UserAvatar(
            avatar: profile.avatar,
            size: 112,
            ring: true,
            heroTag: 'avatar-${profile.uid}',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          Username.display(profile.username),
          style: theme.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        Text(
          profile.displayName,
          style: theme.textTheme.titleMedium?.copyWith(color: muted),
          textAlign: TextAlign.center,
        ),
        if (profile.bio.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            profile.bio,
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
        if (profile.createdAt != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'En FoodReto desde ${DateLabels.monthYear(profile.createdAt!)}',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final tiles = [
              _StatTile(
                emoji: '🔥',
                label: 'Retos',
                value: values?.challengeCount,
              ),
              _StatTile(
                emoji: '🥇',
                label: 'Victorias',
                value: values?.winCount,
              ),
              _StatTile(
                emoji: '⭐',
                label: 'Mejor',
                value: values?.bestScore,
              ),
              _StatTile(
                emoji: '🏆',
                label: 'Récords',
                value: values?.recordCount,
              ),
            ];
            final perRow = constraints.maxWidth < 340 ? 2 : 4;
            return Wrap(
              runSpacing: AppSpacing.sm,
              children: [
                for (final tile in tiles)
                  SizedBox(width: constraints.maxWidth / perRow, child: tile),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.tonalIcon(
          onPressed: () => context.push(AppRoutes.editProfile),
          icon: const Icon(Icons.edit_rounded),
          label: const Text('EDITAR PERFIL'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.friends),
          icon: const Icon(Icons.group_rounded),
          label: const Text('AMIGOS'),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.emoji, required this.label, this.value});

  final String emoji;
  final String label;

  /// `null` mientras carga o si no se pudo leer.
  final int? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: AppSpacing.xs),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: (value ?? 0).toDouble()),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, animated, _) => Text(
            value == null ? '–' : animated.round().toString(),
            style: theme.textTheme.headlineMedium,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ProfileSections extends StatelessWidget {
  const _ProfileSections();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Mis retos',
          actionLabel: 'Ver todos',
          onAction: () => context.go(AppRoutes.challenges),
        ),
        const MyChallengesList(limit: 3),
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(
          title: 'Rankings',
          actionLabel: 'Ver',
          onAction: () => context.go(AppRoutes.rankings),
        ),
        const EmptyStateView(
          compact: true,
          emoji: '👑',
          title: 'Récords y ranking',
          message:
              'Tus estadísticas oficiales (victorias, mejor score, récords) '
              'aparecen arriba cuando Cloud Functions procesa tus retos.',
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(title: 'Categorías favoritas'),
        const EmptyStateView(
          compact: true,
          emoji: '🍗',
          title: 'Sin favoritas todavía',
          message: 'Aparecerán las comidas en las que más compites.',
        ),
      ],
    );
  }
}
