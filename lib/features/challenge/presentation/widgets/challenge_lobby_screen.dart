import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/centered_content.dart';
import '../../../../shared/widgets/fade_slide_in.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../category/presentation/providers/category_providers.dart';
import '../../../restaurant/presentation/providers/restaurant_providers.dart';
import '../../domain/entities/challenge.dart';
import '../providers/challenge_controllers.dart';
import '../providers/challenge_providers.dart';
import '../share/challenge_invite.dart';
import '../../../profile/domain/value_objects/username.dart';
import '../../../social/presentation/providers/social_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import 'challenge_widgets.dart';
import 'participant_tile.dart';

/// Sala de espera: código, compartir y participantes en vivo.
class ChallengeLobbyScreen extends ConsumerWidget {
  const ChallengeLobbyScreen({super.key, required this.challenge});

  final Challenge challenge;

  Future<void> _share(BuildContext context, WidgetRef ref) {
    // Ya están en caché: la cabecera de la sala los está mostrando.
    final category = ref.read(categoryByIdProvider(challenge.categoryId)).value;
    final restaurantId = challenge.restaurantId;
    final restaurant = restaurantId == null
        ? null
        : ref.read(restaurantProvider(restaurantId)).value?.name;
    final config = ref.read(appConfigProvider);
    final link = ChallengeInvite.link(
      baseUrl: ChallengeInvite.baseUrl(config.publicBaseUrl),
      code: challenge.inviteCode,
    );
    final title = challenge.displayTitle(category?.name);
    return shareInvite(
      context,
      subject: title,
      message: ChallengeInvite.message(
        title: title,
        emoji: category?.icon ?? '???',
        code: challenge.inviteCode,
        link: link,
        restaurantName: restaurant,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final uid = ref.watch(currentUidProvider);
    final isHost = challenge.isHost(uid);
    final participants = ref.watch(challengeParticipantsProvider(challenge.id));
    final actions = ref.watch(roomActionsControllerProvider(challenge.id));

    return CenteredContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChallengeHeader(challenge: challenge, large: true),
          if (challenge.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(challenge.description, style: theme.textTheme.bodyLarge),
          ],
          const SizedBox(height: AppSpacing.lg),
          _InviteCard(
            code: challenge.inviteCode,
            onCopy: () => copyInviteCode(context, challenge.inviteCode),
            onShare: () => _share(context, ref),
          ),
          if (isHost) ...[
            const SizedBox(height: AppSpacing.md),
            _InviteFriendsSection(challenge: challenge),
          ],
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
            title:
                'Participantes · ${challenge.participantIds.length}/'
                '${challenge.maxParticipants}',
          ),
          switch (participants) {
            AsyncData(:final value) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, p) in value.indexed)
                  FadeSlideIn(
                    key: ValueKey(p.userId),
                    index: i,
                    child: ParticipantTile(
                      avatar: p.avatar,
                      displayName: p.displayName,
                      username: p.username,
                      isHost: p.isHost,
                      isMe: p.userId == uid,
                    ),
                  ),
              ],
            ),
            AsyncError() => ErrorStateView(
              compact: true,
              message: 'No pudimos cargar a los participantes.',
              onRetry: () =>
                  ref.invalidate(challengeParticipantsProvider(challenge.id)),
            ),
            _ => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
          },
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  challenge.isFull
                      ? 'Sala completa'
                      : (isHost
                            ? 'Esperando participantes…'
                            : 'Esperando al anfitrión…'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (isHost)
            FilledButton.icon(
              onPressed: actions.isBusy
                  ? null
                  : () => ref
                        .read(
                          roomActionsControllerProvider(challenge.id).notifier,
                        )
                        .run(RoomAction.start),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                actions.running == RoomAction.start
                    ? 'INICIANDO…'
                    : 'INICIAR RETO',
              ),
            )
          else
            Text(
              'El anfitrión iniciará el reto cuando estén todos.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.code,
    required this.onCopy,
    required this.onShare,
  });

  final String code;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = OutlinedButton.icon(
      onPressed: onCopy,
      icon: const Icon(Icons.copy_rounded),
      label: const Text('COPIAR'),
    );
    final share = FilledButton.tonalIcon(
      onPressed: onShare,
      icon: const Icon(Icons.ios_share_rounded),
      label: const Text('COMPARTIR RETO'),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Text(
              'Código de invitación',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: SelectableText(
                code,
                semanticsLabel: 'Código ${code.split('').join(' ')}',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth < 360
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        share,
                        const SizedBox(height: AppSpacing.sm),
                        copy,
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: copy),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: share),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteFriendsSection extends ConsumerWidget {
  const _InviteFriendsSection({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsListProvider);
    final uid = ref.watch(currentUidProvider);
    final me = ref.watch(currentUserProfileProvider).value;

    return friends.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (uid == null || me == null || items.isEmpty) {
          return Text(
            'Cuando tengas amigos podrás invitarlos aquí.',
            style: Theme.of(context).textTheme.bodySmall,
          );
        }
        final already = challenge.participantIds.toSet();
        final inviteable = [
          for (final f in items)
            if (!already.contains(f.otherUserId(uid))) f,
        ];
        if (inviteable.isEmpty) {
          return Text(
            'Tus amigos ya están en el reto o no hay a quién invitar.',
            style: Theme.of(context).textTheme.bodySmall,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Invitar amigos',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final f in inviteable.take(12))
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(f.otherSnapshot(uid).displayName),
                subtitle: Text(
                  Username.display(f.otherSnapshot(uid).username),
                ),
                trailing: FilledButton.tonal(
                  onPressed: () async {
                    final other = f.otherSnapshot(uid);
                    // Preferir otherUserId: snapshots viejos pueden no traer userId.
                    final toUid = f.otherUserId(uid);
                    final result = await ref.read(
                      inviteFriendToChallengeProvider,
                    )(
                      challengeId: challenge.id,
                      fromUid: me.uid,
                      toUid: toUid,
                      fromUsername: me.username,
                      fromDisplayName: me.displayName,
                      challengeTitle: challenge.title,
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result.fold(
                            onSuccess: (_) =>
                                'Invitación enviada a ${other.displayName}',
                            onFailure: (e) => e.message,
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Invitar'),
                ),
              ),
          ],
        );
      },
    );
  }
}
