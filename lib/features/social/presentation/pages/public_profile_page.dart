import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/centered_content.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../profile/domain/value_objects/username.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/entities/friendship.dart';
import '../../domain/failures/social_failure.dart';
import '../providers/social_providers.dart';

class PublicProfilePage extends ConsumerWidget {
  const PublicProfilePage({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authStateProvider).value?.id;
    if (me != null && me == userId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(AppRoutes.profile);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final profile = ref.watch(publicProfileProvider(userId));
    final relation = ref.watch(friendshipRelationProvider(userId));
    final stats = ref.watch(publicStatsProvider(userId));
    final friendsCount = ref.watch(friendsCountProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: SafeArea(
        child: CenteredContent(
          child: profile.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) {
              if (e is SocialPrivateProfile) {
                return const EmptyStateView(
                  emoji: '🔒',
                  title: 'Perfil privado',
                  message: 'Este usuario no comparte su perfil públicamente.',
                );
              }
              return EmptyStateView(
                emoji: '🫥',
                title: 'Usuario no encontrado',
                message: e.toString(),
              );
            },
            data: (p) => Column(
              children: [
                UserAvatar(avatar: p.avatar, size: 96),
                const SizedBox(height: AppSpacing.md),
                Text(
                  Username.display(p.username),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(p.displayName),
                if (p.bio.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(p.bio, textAlign: TextAlign.center),
                ],
                const SizedBox(height: AppSpacing.md),
                relation.when(
                  data: (r) => _FriendshipActions(userId: userId, relation: r, profile: p),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: AppSpacing.lg),
                stats.when(
                  data: (s) => Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _ChipStat(label: 'Retos', value: '${s.challengeCount}'),
                      _ChipStat(label: 'Victorias', value: '${s.winCount}'),
                      _ChipStat(label: 'Mejor', value: '${s.bestScore}'),
                      _ChipStat(label: 'Récords', value: '${s.recordCount}'),
                      friendsCount.when(
                        data: (n) => _ChipStat(label: 'Amigos', value: '$n'),
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  loading: () => const CircularProgressIndicator(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipStat extends StatelessWidget {
  const _ChipStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _FriendshipActions extends ConsumerStatefulWidget {
  const _FriendshipActions({
    required this.userId,
    required this.relation,
    required this.profile,
  });

  final String userId;
  final FriendshipRelation relation;
  final UserProfile profile;

  @override
  ConsumerState<_FriendshipActions> createState() => _FriendshipActionsState();
}

class _FriendshipActionsState extends ConsumerState<_FriendshipActions> {
  var _busy = false;

  Future<void> _refresh(String uid) async {
    ref.invalidate(friendshipRelationProvider(widget.userId));
    ref.invalidate(friendsListProvider);
    ref.invalidate(incomingRequestsProvider);
    ref.invalidate(friendsCountProvider(widget.userId));
    ref.invalidate(friendsCountProvider(uid));
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProfileProvider).value;
    final uid = ref.watch(authStateProvider).value?.id;
    if (me == null || uid == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.sm),
        child: CircularProgressIndicator(),
      );
    }

    final relation = widget.relation;
    final userId = widget.userId;
    final profile = widget.profile;

    switch (relation) {
      case FriendshipRelation.self:
        return const SizedBox.shrink();
      case FriendshipRelation.none:
        return FilledButton.icon(
          onPressed: _busy
              ? null
              : () => _run(() async {
                    final result = await ref.read(sendFriendRequestProvider)(
                      from: me,
                      to: profile,
                    );
                    await result.fold(
                      onSuccess: (_) async {
                        _toast('Solicitud enviada');
                        await _refresh(uid);
                      },
                      onFailure: (f) async {
                        _toast(f.message, error: true);
                        await _refresh(uid);
                      },
                    );
                  }),
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.person_add_alt_1_rounded),
          label: Text(_busy ? 'Enviando...' : 'Agregar amigo'),
        );
      case FriendshipRelation.outgoingPending:
        return OutlinedButton(
          onPressed: _busy
              ? null
              : () => _run(() async {
                    final id = Friendship.idFor(uid, userId);
                    final result = await ref.read(cancelFriendRequestProvider)(
                      friendshipId: id,
                      uid: uid,
                    );
                    await result.fold(
                      onSuccess: (_) async {
                        _toast('Solicitud cancelada');
                        await _refresh(uid);
                      },
                      onFailure: (f) async {
                        _toast(f.message, error: true);
                        await _refresh(uid);
                      },
                    );
                  }),
          child: Text(
            _busy ? 'Cancelando...' : 'Solicitud enviada · Cancelar',
          ),
        );
      case FriendshipRelation.incomingPending:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                        final id = Friendship.idFor(uid, userId);
                        final result =
                            await ref.read(rejectFriendRequestProvider)(
                          friendshipId: id,
                          uid: uid,
                        );
                        await result.fold(
                          onSuccess: (_) async {
                            _toast('Solicitud rechazada');
                            await _refresh(uid);
                          },
                          onFailure: (f) async {
                            _toast(f.message, error: true);
                          },
                        );
                      }),
              child: const Text('Rechazar'),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                        final id = Friendship.idFor(uid, userId);
                        final result =
                            await ref.read(acceptFriendRequestProvider)(
                          friendshipId: id,
                          uid: uid,
                        );
                        await result.fold(
                          onSuccess: (_) async {
                            _toast('Ahora son amigos');
                            await _refresh(uid);
                          },
                          onFailure: (f) async {
                            _toast(f.message, error: true);
                          },
                        );
                      }),
              child: const Text('Aceptar'),
            ),
          ],
        );
      case FriendshipRelation.friends:
        return OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => _run(() async {
                    final id = Friendship.idFor(uid, userId);
                    final result = await ref.read(removeFriendProvider)(
                      friendshipId: id,
                      uid: uid,
                    );
                    await result.fold(
                      onSuccess: (_) async {
                        _toast('Amistad eliminada');
                        await _refresh(uid);
                      },
                      onFailure: (f) async {
                        _toast(f.message, error: true);
                      },
                    );
                  }),
          icon: const Icon(Icons.person_remove_alt_1_rounded),
          label: const Text('Amigos · Eliminar'),
        );
    }
  }
}
