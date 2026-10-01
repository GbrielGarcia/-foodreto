import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firestore_error_mapper.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../domain/entities/establishment_status.dart';
import '../../domain/entities/restaurant.dart';

abstract final class RestaurantDto {
  static Restaurant? fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) return null;
    final name = data['name'];
    if (name is! String || name.trim().isEmpty) return null;

    String text(String key) {
      final value = data[key];
      return value is String ? value : '';
    }

    double? number(String key) {
      final value = data[key];
      return value is num ? value.toDouble() : null;
    }

    List<String> urls(String key, {int max = 12}) {
      final raw = data[key];
      if (raw is! List) return const [];
      final out = <String>[];
      for (final item in raw) {
        if (item is! String) continue;
        final t = item.trim();
        if (t.isEmpty || !t.startsWith('http')) continue;
        out.add(t);
        if (out.length >= max) break;
      }
      return out;
    }

    final slug = text('slug');
    final normalized = text('normalizedName').isNotEmpty
        ? text('normalizedName')
        : text('nameLower');
    final categoryIds = <String>[
      for (final id in data['categoryIds'] as List? ?? const [])
        if (id is String && id.isNotEmpty) id,
    ];
    final image = text('imageUrl');
    final logo = text('logoUrl');

    final statusRaw = data['status'] as String?;
    final EstablishmentStatus status;
    if (statusRaw != null && statusRaw.isNotEmpty) {
      status = EstablishmentStatus.fromId(statusRaw);
    } else {
      status = data['isActive'] == false
          ? EstablishmentStatus.suspended
          : EstablishmentStatus.approved;
    }

    return Restaurant(
      id: id,
      name: name.trim(),
      slug: slug.isNotEmpty ? slug : TextNormalizer.slugify(name),
      normalizedName: normalized.isNotEmpty
          ? normalized
          : TextNormalizer.normalize(name),
      address: text('address'),
      description: text('description'),
      imageUrl: image.isEmpty ? null : image,
      logoUrl: logo.isEmpty ? null : logo,
      categoryIds: categoryIds,
      city: text('city'),
      country: text('country').toUpperCase(),
      latitude: number('latitude'),
      longitude: number('longitude'),
      isActive: status.isPubliclyDiscoverable,
      status: status,
      creatorUserId: text('creatorUserId').isEmpty
          ? null
          : text('creatorUserId'),
      ownerUserId:
          text('ownerUserId').isEmpty ? null : text('ownerUserId'),
      phone: text('phone'),
      whatsapp: text('whatsapp'),
      websiteUrl: text('websiteUrl'),
      instagramUrl: text('instagramUrl'),
      facebookUrl: text('facebookUrl'),
      tiktokUrl: text('tiktokUrl'),
      galleryUrls: urls('galleryUrls', max: Restaurant.maxGalleryImages),
      videoUrls: urls('videoUrls', max: Restaurant.maxVideoLinks),
      createdAt: readTimestamp(data['createdAt']),
      updatedAt: readTimestamp(data['updatedAt']),
      approvedAt: readTimestamp(data['approvedAt']),
      approvedByUserId: text('approvedByUserId').isEmpty
          ? null
          : text('approvedByUserId'),
      rejectedAt: readTimestamp(data['rejectedAt']),
      rejectedByUserId: text('rejectedByUserId').isEmpty
          ? null
          : text('rejectedByUserId'),
      rejectionReason: text('rejectionReason').isEmpty
          ? null
          : text('rejectionReason'),
      suspendedAt: readTimestamp(data['suspendedAt']),
      suspendedByUserId: text('suspendedByUserId').isEmpty
          ? null
          : text('suspendedByUserId'),
      suspensionReason: text('suspensionReason').isEmpty
          ? null
          : text('suspensionReason'),
    );
  }

  static Map<String, Object?> toCreateRequestMap({
    required String name,
    required String city,
    required String country,
    required String creatorUid,
    String address = '',
    String description = '',
    String? imageUrl,
    List<String> categoryIds = const [],
    double? latitude,
    double? longitude,
  }) {
    final trimmed = name.trim();
    final normalized = TextNormalizer.normalize(trimmed);
    return {
      'name': trimmed,
      'slug': TextNormalizer.slugify(trimmed),
      'normalizedName': normalized,
      'nameLower': normalized,
      'city': city.trim(),
      'country': country.trim().toUpperCase(),
      'address': address.trim(),
      'description': description.trim(),
      'imageUrl': imageUrl,
      'categoryIds': categoryIds,
      'latitude': latitude,
      'longitude': longitude,
      'phone': '',
      'whatsapp': '',
      'websiteUrl': '',
      'instagramUrl': '',
      'facebookUrl': '',
      'tiktokUrl': '',
      'galleryUrls': <String>[],
      'videoUrls': <String>[],
      'creatorUserId': creatorUid,
      'ownerUserId': creatorUid,
      'status': EstablishmentStatus.pending.name,
      'isActive': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Map<String, Object?> toOwnerUpdateMap({
    String? name,
    String? city,
    String? country,
    String? address,
    String? description,
    String? imageUrl,
    String? logoUrl,
    List<String>? categoryIds,
    double? latitude,
    double? longitude,
    String? phone,
    String? whatsapp,
    String? websiteUrl,
    String? instagramUrl,
    String? facebookUrl,
    String? tiktokUrl,
    List<String>? galleryUrls,
    List<String>? videoUrls,
  }) {
    final out = <String, Object?>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (name != null) {
      final trimmed = name.trim();
      final normalized = TextNormalizer.normalize(trimmed);
      out['name'] = trimmed;
      out['slug'] = TextNormalizer.slugify(trimmed);
      out['normalizedName'] = normalized;
      out['nameLower'] = normalized;
    }
    if (city != null) out['city'] = city.trim();
    if (country != null) out['country'] = country.trim().toUpperCase();
    if (address != null) out['address'] = address.trim();
    if (description != null) out['description'] = description.trim();
    if (imageUrl != null) out['imageUrl'] = imageUrl;
    if (logoUrl != null) out['logoUrl'] = logoUrl;
    if (categoryIds != null) out['categoryIds'] = categoryIds;
    if (latitude != null) out['latitude'] = latitude;
    if (longitude != null) out['longitude'] = longitude;
    if (phone != null) out['phone'] = phone.trim();
    if (whatsapp != null) out['whatsapp'] = whatsapp.trim();
    if (websiteUrl != null) out['websiteUrl'] = websiteUrl.trim();
    if (instagramUrl != null) out['instagramUrl'] = instagramUrl.trim();
    if (facebookUrl != null) out['facebookUrl'] = facebookUrl.trim();
    if (tiktokUrl != null) out['tiktokUrl'] = tiktokUrl.trim();
    if (galleryUrls != null) {
      out['galleryUrls'] =
          galleryUrls.take(Restaurant.maxGalleryImages).toList();
    }
    if (videoUrls != null) {
      out['videoUrls'] = videoUrls.take(Restaurant.maxVideoLinks).toList();
    }
    return out;
  }
}
