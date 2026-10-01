abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const onboarding = '/onboarding';

  // Pestañas
  static const home = '/';
  static const explore = '/explore';
  static const challenges = '/challenges';
  static const rankings = '/rankings';
  static const profile = '/profile';

  static const editProfile = '/profile/edit';
  static const publicProfile = '/u/:userId';
  static String publicProfilePath(String userId) => '/u/$userId';

  static const friends = '/friends';
  static const friendRequests = '/friends/requests';
  static const userSearch = '/friends/search';
  static const feed = '/feed';
  static const notifications = '/notifications';
  static const categories = '/categories';
  static const category = '/category/:slug';
  static String categoryPath(String slug) => '/category/$slug';

  static const create = '/create';
  static String createPath({String? categoryId}) => categoryId == null
      ? create
      : Uri(path: create, queryParameters: {'category': categoryId}).toString();

  static const restaurant = '/restaurant/:restaurantId';
  static String restaurantPath(String restaurantId) =>
      '/restaurant/$restaurantId';
  static const restaurantRanking = '/restaurant/:restaurantId/ranking';
  static String restaurantRankingPath(
    String restaurantId, {
    String? categoryId,
  }) {
    final base = '/restaurant/$restaurantId/ranking';
    if (categoryId == null) return base;
    return Uri(
      path: base,
      queryParameters: {'category': categoryId},
    ).toString();
  }

  static const createEstablishment = '/establishments/create';
  static const myEstablishments = '/establishments/mine';
  static const editEstablishment = '/establishments/:id/edit';
  static String editEstablishmentPath(String id) => '/establishments/$id/edit';

  /// Panel Super Admin (shell propio, no el de usuarios).
  static const admin = '/admin';
  static const adminEstablishments = '/admin/establishments';
  static const adminEstablishment = '/admin/establishments/:id';
  static String adminEstablishmentPath(String id) => '/admin/establishments/$id';
  static const adminAccount = '/admin/account';

  /// Sala del reto: espera, contador y resultado según su estado.
  static const challengeRoom = '/challenges/:id';
  static String challengePath(String id) => '/challenges/$id';

  static const join = '/join/:code';
  static String joinPath(String code) => '/join/$code';

  static const publicAuthRoutes = {login, register};
}
