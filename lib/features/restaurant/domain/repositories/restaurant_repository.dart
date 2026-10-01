import '../../../../core/error/result.dart';
import '../entities/establishment_status.dart';
import '../entities/restaurant.dart';

/// Campos publicos para solicitud de establecimiento (Fase 9.1).
class CreateEstablishmentRequest {
  const CreateEstablishmentRequest({
    required this.name,
    required this.city,
    required this.country,
    required this.creatorUid,
    this.address = '',
    this.description = '',
    this.imageUrl,
    this.categoryIds = const [],
    this.latitude,
    this.longitude,
  });

  final String name;
  final String city;
  final String country;
  final String creatorUid;
  final String address;
  final String description;
  final String? imageUrl;
  final List<String> categoryIds;
  final double? latitude;
  final double? longitude;
}

class OwnerEstablishmentUpdate {
  const OwnerEstablishmentUpdate({
    this.name,
    this.city,
    this.country,
    this.address,
    this.description,
    this.imageUrl,
    this.logoUrl,
    this.categoryIds,
    this.latitude,
    this.longitude,
    this.phone,
    this.whatsapp,
    this.websiteUrl,
    this.instagramUrl,
    this.facebookUrl,
    this.tiktokUrl,
    this.galleryUrls,
    this.videoUrls,
  });

  final String? name;
  final String? city;
  final String? country;
  final String? address;
  final String? description;
  final String? imageUrl;
  final String? logoUrl;
  final List<String>? categoryIds;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final String? whatsapp;
  final String? websiteUrl;
  final String? instagramUrl;
  final String? facebookUrl;
  final String? tiktokUrl;
  final List<String>? galleryUrls;
  final List<String>? videoUrls;
}

class RestaurantPage {
  const RestaurantPage({required this.items, this.nextCursor});

  final List<Restaurant> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}

abstract interface class RestaurantRepository {
  Future<Result<Restaurant?>> getById(String id);

  Future<Result<Restaurant?>> getBySlug(String slug);

  /// Busqueda por prefijo del nombre normalizado ("wing" -> "Wing House").
  Future<Result<List<Restaurant>>> searchByName(String query, {int limit = 20});

  /// Pagina de restaurantes activos (orden createdAt DESC).
  Future<Result<RestaurantPage>> getRestaurantsPage({
    int limit = 20,
    String? cursor,
    String? city,
    String? categoryId,
  });

  /// Busqueda combinada (nombre / ciudad). Debounce en providers.
  Future<Result<List<Restaurant>>> searchRestaurants({
    required String query,
    int limit = 20,
  });

  /// Crea solicitud `status=pending` (reglas Firestore).
  Future<Result<String>> createRequest(CreateEstablishmentRequest request);

  /// Establecimientos creados o de los que es dueno el usuario.
  Future<Result<List<Restaurant>>> listMine(String uid);

  /// Cola admin por estado (Super Admin / reglas).
  Future<Result<RestaurantPage>> listByStatus(
    EstablishmentStatus status, {
    int limit = 20,
    String? cursor,
  });

  /// Solo campos publicos; no cambia status ni ownership.
  Future<Result<void>> updateOwnerFields({
    required String id,
    required String ownerUid,
    required OwnerEstablishmentUpdate update,
  });

  /// Posibles duplicados por nombre normalizado + ciudad.
  Future<Result<List<Restaurant>>> findPossibleDuplicates(
    String nameLower,
    String city,
  );
}
