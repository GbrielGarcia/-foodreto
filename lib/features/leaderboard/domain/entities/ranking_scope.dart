/// Ámbitos de ranking/récord. Siempre se documentan con [scopeKey].
enum RankingScopeType { global, category, restaurantCategory }

/// Claves estables usadas en `leaderboards/{scopeKey}`.
abstract final class RankingScopes {
  static const global = 'global';

  static String category(String categoryId) => 'global:cat:$categoryId';

  static String restaurantCategory(String restaurantId, String categoryId) =>
      'restaurant:$restaurantId:cat:$categoryId';

  static RankingScopeType typeOf(String scopeKey) {
    if (scopeKey == global) return RankingScopeType.global;
    if (scopeKey.startsWith('restaurant:') && scopeKey.contains(':cat:')) {
      return RankingScopeType.restaurantCategory;
    }
    if (scopeKey.startsWith('global:cat:')) return RankingScopeType.category;
    return RankingScopeType.global;
  }

  /// Scopes públicos derivados de un resultado.
  static List<String> forResult({
    required String categoryId,
    String? restaurantId,
  }) {
    final scopes = <String>[global, category(categoryId)];
    final restaurant = restaurantId;
    if (restaurant != null && restaurant.isNotEmpty) {
      scopes.add(restaurantCategory(restaurant, categoryId));
    }
    return scopes;
  }
}
