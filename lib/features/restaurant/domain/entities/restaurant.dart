import 'establishment_status.dart';

/// Restaurante / establecimiento (`restaurants/{restaurantId}`).
///
/// Fase 9.1: [creatorUserId] nunca cambia; [ownerUserId] solo via Super Admin.
/// Fase 9.2: ficha publica enriquecida (contacto, redes, galeria, videos URL).
/// [isActive] sincronizado con [status] == approved.
class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.slug,
    required this.normalizedName,
    required this.city,
    required this.country,
    this.address = '',
    this.description = '',
    this.imageUrl,
    this.logoUrl,
    this.categoryIds = const [],
    this.latitude,
    this.longitude,
    this.isActive = true,
    this.status = EstablishmentStatus.approved,
    this.creatorUserId,
    this.ownerUserId,
    this.phone = '',
    this.whatsapp = '',
    this.websiteUrl = '',
    this.instagramUrl = '',
    this.facebookUrl = '',
    this.tiktokUrl = '',
    this.galleryUrls = const [],
    this.videoUrls = const [],
    this.createdAt,
    this.updatedAt,
    this.approvedAt,
    this.approvedByUserId,
    this.rejectedAt,
    this.rejectedByUserId,
    this.rejectionReason,
    this.suspendedAt,
    this.suspendedByUserId,
    this.suspensionReason,
  });

  static const maxGalleryImages = 12;
  static const maxVideoLinks = 6;

  final String id;
  final String name;

  /// Para URLs publicas (`/restaurant/wing-house`).
  final String slug;

  /// Minusculas sin acentos: busqueda y duplicados.
  final String normalizedName;

  /// Alias de [normalizedName] (brief Fase 9: nameLower).
  String get nameLower => normalizedName;

  final String address;
  final String description;

  /// Portada / banner horizontal.
  final String? imageUrl;

  /// Foto de perfil circular del local (avatar).
  final String? logoUrl;

  /// Avatar para listas: logo circular, o portada como fallback.
  String? get displayAvatarUrl =>
      (logoUrl != null && logoUrl!.isNotEmpty) ? logoUrl : imageUrl;

  final List<String> categoryIds;
  final String city;

  /// Codigo ISO-3166 alfa-2 (`EC`, `DO`...).
  final String country;
  final double? latitude;
  final double? longitude;

  /// Compat: true solo si [status] == approved (descubrimiento publico).
  final bool isActive;

  final EstablishmentStatus status;

  /// Usuario que creo la solicitud. Inmutable.
  final String? creatorUserId;

  /// Responsable actual del establecimiento (control en FoodReto).
  final String? ownerUserId;

  /// Contacto publico (Fase 9.2).
  final String phone;
  final String whatsapp;
  final String websiteUrl;
  final String instagramUrl;
  final String facebookUrl;
  final String tiktokUrl;

  /// Galeria de imagenes (URLs Storage o https). Max [maxGalleryImages].
  final List<String> galleryUrls;

  /// Videos por enlace externo (YouTube / TikTok / Vimeo). Max [maxVideoLinks].
  /// No se suben binarios de video (costo / Spark).
  final List<String> videoUrls;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? approvedAt;
  final String? approvedByUserId;
  final DateTime? rejectedAt;
  final String? rejectedByUserId;
  final String? rejectionReason;
  final DateTime? suspendedAt;
  final String? suspendedByUserId;
  final String? suspensionReason;

  bool get hasLocation => latitude != null && longitude != null;

  bool get hasContact =>
      phone.isNotEmpty ||
      whatsapp.isNotEmpty ||
      websiteUrl.isNotEmpty ||
      instagramUrl.isNotEmpty ||
      facebookUrl.isNotEmpty ||
      tiktokUrl.isNotEmpty;

  bool isOwner(String uid) => ownerUserId == uid;
  bool isCreator(String uid) => creatorUserId == uid;

  /// Puede gestionar ficha publica (solo approved + owner).
  bool canOwnerManage(String uid) =>
      isOwner(uid) && status == EstablishmentStatus.approved;
}
