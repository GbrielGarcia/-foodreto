import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/avatar/avatar_config.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/centered_content.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/domain/value_objects/username.dart';
import '../../domain/entities/friendship.dart';
import '../providers/social_providers.dart';

class FriendsPage extends ConsumerStatefulWidget {
  const FriendsPage({super.key});

  @override
  ConsumerState<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends ConsumerState<FriendsPage> {
  final _search = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final friends = ref.watch(friendsListProvider);
    final uid = ref.watch(authStateProvider).value?.id;
    final filteredQuery = _query.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Amigos'),
        actions: [
          IconButton(
            tooltip: 'Solicitudes',
            onPressed: () => context.push(AppRoutes.friendRequests),
            icon: const Icon(Icons.mail_outline_rounded),
          ),
          IconButton(
            tooltip: 'Buscar usuarios',
            onPressed: () => context.push(AppRoutes.userSearch),
            icon: const Icon(Icons.person_search_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: CenteredContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Filtrar amigos…',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: AppSpacing.md),
              friends.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => EmptyStateView(
                  emoji: '⚠️',
                  title: 'No se pudo cargar',
                  message: e.toString(),
                ),
                data: (items) {
                  if (uid == null) {
                    return const EmptyStateView(
                      emoji: '🔒',
                      title: 'Inicia sesión',
                      message: 'Necesitas una cuenta para ver amigos.',
                    );
                  }
                  final visible = [
                    for (final f in items)
                      if (filteredQuery.isEmpty ||
                          f.otherSnapshot(uid).username.contains(filteredQuery) ||
                          f
                              .otherSnapshot(uid)
                              .displayName
                              .toLowerCase()
                              .contains(filteredQuery))
                        f,
                  ];
                  if (items.isEmpty) {
                    return EmptyStateView(
                      emoji: '👋',
                      title: 'Aún no tienes amigos',
                      message: 'Busca usuarios y envía solicitudes.',
                      actionLabel: 'Buscar usuarios',
                      onAction: () => context.push(AppRoutes.userSearch),
                    );
                  }
                  if (visible.isEmpty) {
                    return const EmptyStateView(
                      compact: true,
                      emoji: '🔍',
                      title: 'Sin coincidencias',
                      message: 'Prueba con otro nombre o @username.',
                    );
                  }
                  return Column(
                    children: [
                      for (final f in visible)
                        _FriendTile(friendship: f, currentUid: uid),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Ranking entre amigos', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              const _FriendsRankingPreview(),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friendship, required this.currentUid});

  final Friendship friendship;
  final String currentUid;

  @override
  Widget build(BuildContext context) {
    final other = friendship.otherSnapshot(currentUid);
    final avatar = AvatarConfig.fromData(
      style: other.avatarStyle,
      seed: other.avatarSeed,
    );
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: UserAvatar(avatar: avatar, size: 44),
      title: Text(other.displayName),
      subtitle: Text(Username.display(other.username)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.push(AppRoutes.publicProfilePath(other.userId)),
    );
  }
}

class _FriendsRankingPreview extends ConsumerWidget {
  const _FriendsRankingPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ranking = ref.watch(friendsRankingProvider(null));
    return ranking.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text(e.toString()),
      data: (entries) {
        if (entries.isEmpty) {
          return const EmptyStateView(
            compact: true,
            emoji: '🏆',
            title: 'Sin ranking todavía',
            message:
                'Cuando tú o tus amigos tengan scores oficiales aparecerán aquí.',
          );
        }
        return Column(
          children: [
            for (final e in entries.take(8))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text('#${e.position ?? '–'}'),
                title: Text(e.displayName),
                trailing: Text('${e.bestScore}'),
                onTap: () =>
                    context.push(AppRoutes.publicProfilePath(e.userId)),
              ),
          ],
        );
      },
    );
  }
}
