import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/avatar/avatar_config.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/widgets/centered_content.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/domain/value_objects/username.dart';
import '../providers/social_providers.dart';

class FriendRequestsPage extends ConsumerWidget {
  const FriendRequestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(incomingRequestsProvider);
    final uid = ref.watch(authStateProvider).value?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitudes')),
      body: SafeArea(
        child: CenteredContent(
          child: requests.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => EmptyStateView(
              emoji: '⚠️',
              title: 'Error',
              message: e.toString(),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const EmptyStateView(
                  emoji: '📭',
                  title: 'Sin solicitudes',
                  message: 'Cuando alguien te agregue aparecerá aquí.',
                );
              }
              return Column(
                children: [
                  for (final f in items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: UserAvatar(
                        avatar: AvatarConfig.fromData(
                          style: f.requester.avatarStyle,
                          seed: f.requester.avatarSeed,
                        ),
                        size: 44,
                      ),
                      title: Text(f.requester.displayName),
                      subtitle: Text(Username.display(f.requester.username)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Rechazar',
                            onPressed: uid == null
                                ? null
                                : () async {
                                    await ref
                                        .read(rejectFriendRequestProvider)(
                                      friendshipId: f.id,
                                      uid: uid,
                                    );
                                    ref.invalidate(incomingRequestsProvider);
                                    ref.invalidate(friendsListProvider);
                                  },
                            icon: const Icon(Icons.close_rounded),
                          ),
                          FilledButton(
                            onPressed: uid == null
                                ? null
                                : () async {
                                    await ref
                                        .read(acceptFriendRequestProvider)(
                                      friendshipId: f.id,
                                      uid: uid,
                                    );
                                    ref.invalidate(incomingRequestsProvider);
                                    ref.invalidate(friendsListProvider);
                                  },
                            child: const Text('Aceptar'),
                          ),
                        ],
                      ),
                      onTap: () => context.push(
                        AppRoutes.publicProfilePath(f.requester.userId),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
