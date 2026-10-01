import '../../../../core/avatar/avatar_config.dart';

/// Resultado de búsqueda pública (solo perfiles visibles).
class UserSearchHit {
  const UserSearchHit({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.avatar,
  });

  final String uid;
  final String username;
  final String displayName;
  final AvatarConfig avatar;
}

class UserSearchPage {
  const UserSearchPage({required this.hits, this.nextCursor});

  final List<UserSearchHit> hits;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}
