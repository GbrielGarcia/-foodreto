import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../domain/entities/establishment_status.dart';
import '../../domain/entities/restaurant.dart';
import '../../domain/repositories/restaurant_repository.dart';

/// Modo local y tests. Empieza vacio: no se inventan restaurantes.
class InMemoryRestaurantRepository implements RestaurantRepository {
  InMemoryRestaurantRepository([List<Restaurant> restaurants = const []])
      : _restaurants = List.of(restaurants);

  final List<Restaurant> _restaurants;

  void seed(Restaurant restaurant) {
    _restaurants.removeWhere((r) => r.id == restaurant.id);
    _restaurants.add(restaurant);
  }

  Iterable<Restaurant> get _active => _restaurants.where((r) => r.isActive);

  @override
  Future<Result<Restaurant?>> getById(String id) async {
    for (final r in _active) {
      if (r.id == id) return Result.success(r);
    }
    return const Result.success(null);
  }

  @override
  Future<Result<Restaurant?>> getBySlug(String slug) async {
    for (final r in _active) {
      if (r.slug == slug) return Result.success(r);
    }
    return const Result.success(null);
  }

  @override
  Future<Result<List<Restaurant>>> searchByName(
    String query, {
    int limit = 20,
  }) async {
    final prefix = TextNormalizer.normalize(query);
    if (prefix.isEmpty) return const Result.success([]);
    final matches =
        _active.where((r) => r.normalizedName.startsWith(prefix)).toList()
          ..sort((a, b) => a.normalizedName.compareTo(b.normalizedName));
    return Result.success(matches.take(limit).toList());
  }

  @override
  Future<Result<RestaurantPage>> getRestaurantsPage({
    int limit = 20,
    String? cursor,
    String? city,
    String? categoryId,
  }) async {
    var list = _active.toList()
      ..sort((a, b) {
        final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });
    if (city != null && city.trim().isNotEmpty) {
      final c = city.trim().toLowerCase();
      list = list.where((r) => r.city.toLowerCase() == c).toList();
    }
    if (categoryId != null && categoryId.isNotEmpty) {
      list = list.where((r) => r.categoryIds.contains(categoryId)).toList();
    }
    var start = 0;
    if (cursor != null) {
      final idx = list.indexWhere((r) => r.id == cursor);
      start = idx < 0 ? 0 : idx + 1;
    }
    final page = list.skip(start).take(limit).toList();
    final next = start + page.length < list.length && page.isNotEmpty
        ? page.last.id
        : null;
    return Result.success(RestaurantPage(items: page, nextCursor: next));
  }

  @override
  Future<Result<List<Restaurant>>> searchRestaurants({
    required String query,
    int limit = 20,
  }) async {
    final q = TextNormalizer.normalize(query);
    final raw = query.trim().toLowerCase();
    if (q.isEmpty && raw.isEmpty) return const Result.success([]);
    final matches = _active.where((r) {
      return r.normalizedName.contains(q) ||
          r.city.toLowerCase().contains(raw) ||
          r.name.toLowerCase().contains(raw);
    }).toList();
    return Result.success(matches.take(limit).toList());
  }

  @override
  Future<Result<String>> createRequest(CreateEstablishmentRequest request) async {
    final id = 'est_${_restaurants.length + 1}';
    final trimmed = request.name.trim();
    final normalized = TextNormalizer.normalize(trimmed);
    final now = DateTime.now();
    _restaurants.add(
      Restaurant(
        id: id,
        name: trimmed,
        slug: TextNormalizer.slugify(trimmed),
        normalizedName: normalized,
        city: request.city.trim(),
        country: request.country.trim().toUpperCase(),
        address: request.address.trim(),
        description: request.description.trim(),
        imageUrl: request.imageUrl,
        categoryIds: request.categoryIds,
        latitude: request.latitude,
        longitude: request.longitude,
        isActive: false,
        status: EstablishmentStatus.pending,
        creatorUserId: request.creatorUid,
        ownerUserId: request.creatorUid,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return Result.success(id);
  }

  @override
  Future<Result<List<Restaurant>>> listMine(String uid) async {
    final list = _restaurants
        .where((r) => r.creatorUserId == uid || r.ownerUserId == uid)
        .toList()
      ..sort((a, b) {
        final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });
    return Result.success(list);
  }

  @override
  Future<Result<RestaurantPage>> listByStatus(
    EstablishmentStatus status, {
    int limit = 20,
    String? cursor,
  }) async {
    var list = _restaurants.where((r) => r.status == status).toList()
      ..sort((a, b) {
        final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });
    var start = 0;
    if (cursor != null) {
      final idx = list.indexWhere((r) => r.id == cursor);
      start = idx < 0 ? 0 : idx + 1;
    }
    final page = list.skip(start).take(limit).toList();
    final next = start + page.length < list.length && page.isNotEmpty
        ? page.last.id
        : null;
    return Result.success(RestaurantPage(items: page, nextCursor: next));
  }

  @override
  Future<Result<void>> updateOwnerFields({
    required String id,
    required String ownerUid,
    required OwnerEstablishmentUpdate update,
  }) async {
    final idx = _restaurants.indexWhere((r) => r.id == id);
    if (idx < 0) {
      return const Result.failure(UnexpectedFailure('No encontrado'));
    }
    final cur = _restaurants[idx];
    if (cur.ownerUserId != ownerUid) {
      return const Result.failure(UnexpectedFailure('Solo el dueno'));
    }
    final name = update.name?.trim() ?? cur.name;
    final normalized = update.name != null
        ? TextNormalizer.normalize(name)
        : cur.normalizedName;
    _restaurants[idx] = Restaurant(
      id: cur.id,
      name: name,
      slug: update.name != null ? TextNormalizer.slugify(name) : cur.slug,
      normalizedName: normalized,
      city: update.city?.trim() ?? cur.city,
      country: update.country?.trim().toUpperCase() ?? cur.country,
      address: update.address?.trim() ?? cur.address,
      description: update.description?.trim() ?? cur.description,
      imageUrl: update.imageUrl ?? cur.imageUrl,
      logoUrl: update.logoUrl ?? cur.logoUrl,
      categoryIds: update.categoryIds ?? cur.categoryIds,
      latitude: update.latitude ?? cur.latitude,
      longitude: update.longitude ?? cur.longitude,
      isActive: cur.isActive,
      status: cur.status,
      creatorUserId: cur.creatorUserId,
      ownerUserId: cur.ownerUserId,
      phone: update.phone?.trim() ?? cur.phone,
      whatsapp: update.whatsapp?.trim() ?? cur.whatsapp,
      websiteUrl: update.websiteUrl?.trim() ?? cur.websiteUrl,
      instagramUrl: update.instagramUrl?.trim() ?? cur.instagramUrl,
      facebookUrl: update.facebookUrl?.trim() ?? cur.facebookUrl,
      tiktokUrl: update.tiktokUrl?.trim() ?? cur.tiktokUrl,
      galleryUrls: update.galleryUrls ?? cur.galleryUrls,
      videoUrls: update.videoUrls ?? cur.videoUrls,
      createdAt: cur.createdAt,
      updatedAt: DateTime.now(),
      approvedAt: cur.approvedAt,
      approvedByUserId: cur.approvedByUserId,
      rejectedAt: cur.rejectedAt,
      rejectedByUserId: cur.rejectedByUserId,
      rejectionReason: cur.rejectionReason,
      suspendedAt: cur.suspendedAt,
      suspendedByUserId: cur.suspendedByUserId,
      suspensionReason: cur.suspensionReason,
    );
    return const Result.success(null);
  }

  @override
  Future<Result<List<Restaurant>>> findPossibleDuplicates(
    String nameLower,
    String city,
  ) async {
    final n = nameLower.trim().toLowerCase();
    final c = city.trim().toLowerCase();
    if (n.isEmpty || c.isEmpty) return const Result.success([]);
    final matches = _restaurants
        .where(
          (r) =>
              r.normalizedName == n && r.city.toLowerCase() == c,
        )
        .toList();
    return Result.success(matches);
  }
}
