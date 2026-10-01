import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/centered_content.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../profile/domain/value_objects/username.dart';
import '../providers/social_providers.dart';

class UserSearchPage extends ConsumerStatefulWidget {
  const UserSearchPage({super.key});

  @override
  ConsumerState<UserSearchPage> createState() => _UserSearchPageState();
}

class _UserSearchPageState extends ConsumerState<UserSearchPage> {
  final _controller = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = _query.trim().isEmpty
        ? null
        : ref.watch(userSearchProvider(_query));

    return Scaffold(
      appBar: AppBar(title: const Text('Buscar usuarios')),
      body: SafeArea(
        child: CenteredContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '@username o nombre',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: AppSpacing.md),
              if (results == null)
                const EmptyStateView(
                  compact: true,
                  emoji: '🔎',
                  title: 'Busca gente',
                  message: 'Escribe un @username o parte del nombre.',
                )
              else
                results.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => EmptyStateView(
                    emoji: '⚠️',
                    title: 'Error de búsqueda',
                    message: e.toString(),
                  ),
                  data: (page) {
                    if (page.hits.isEmpty) {
                      return const EmptyStateView(
                        emoji: '🫥',
                        title: 'Usuario no encontrado',
                        message: 'Prueba con otro @username.',
                      );
                    }
                    return Column(
                      children: [
                        for (final hit in page.hits)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: UserAvatar(avatar: hit.avatar, size: 44),
                            title: Text(hit.displayName),
                            subtitle: Text(Username.display(hit.username)),
                            onTap: () => context.push(
                              AppRoutes.publicProfilePath(hit.uid),
                            ),
                          ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
