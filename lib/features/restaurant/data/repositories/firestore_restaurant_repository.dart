import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/firebase/firestore_collections.dart';
import '../../../../core/firebase/firestore_error_mapper.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../domain/entities/establishment_status.dart';
import '../../domain/entities/restaurant.dart';
import '../../domain/repositories/restaurant_repository.dart';
import '../models/restaurant_dto.dart';

/// Lectura publica de establecimientos.
///
/// Descubrimiento: `status == approved` (Fase 9.1) y legacy `isActive == true`.
class FirestoreRestaurantRepository implements RestaurantRepository {
  FirestoreRestaurantRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _restaurants =>
      _db.collection(FirestoreCollections.restaurants);

  /// Une docs aprobados (status) + legacy activos (isActive).
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _discoverableDocs({
    required int limit,
    String? city,
    String? categoryId,
    bool orderByCreatedAt = false,
  }) async {
    Future<QuerySnapshot<Map<String, dynamic>>> run({
      required String field,
      required Object value,
      required bool withOrder,
    }) {
      Query<Map<String, dynamic>> q = _restaurants.where(field, isEqualTo: value);
      if (city != null && city.trim().isNotEmpty) {
        q = q.where('city', isEqualTo: city.trim());
      }
      if (categoryId != null && categoryId.isNotEmpty) {
        q = q.where('categoryIds', arrayContains: categoryId);
      }
      if (withOrder) {
        q = q.orderBy('createdAt', descending: true);
      }
      return q.limit(limit).get();
    }

    Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> one(
      String field,
      Object value,
    ) async {
      try {
        final snap = await run(
          field: field,
          value: value,
          withOrder: orderByCreatedAt,
        );
        return snap.docs;
      } on FirebaseException catch (e) {
        if (e.code == 'failed-precondition' && orderByCreatedAt) {
          final snap = await run(field: field, value: value, withOrder: false);
          return snap.docs;
        }
        rethrow;
      }
    }

    final approved = await one('status', EstablishmentStatus.approved.name);
    List<QueryDocumentSnapshot<Map<String, dynamic>>> legacy = const [];
    try {
      legacy = await one('isActive', true);
    } catch (_) {
      // Legacy opcional; status approved ya cubre el flujo nuevo.
    }

    final seen = <String>{};
    final out = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final d in [...approved, ...legacy]) {
      if (!seen.add(d.id)) continue;
      final data = d.data();
      final status = data['status'] as String?;
      // Si tiene status y no es approved, no publicar (p.ej. isActive viejo).
      if (status != null &&
          status.isNotEmpty &&
          status != EstablishmentStatus.approved.name) {
        continue;
      }
      out.add(d);
      if (out.length >= limit) break;
    }
    out.sort((a, b) {
      final ta = a.data()['createdAt'];
      final tb = b.data()['createdAt'];
      final da = ta is Timestamp
          ? ta.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0);
      final db_ = tb is Timestamp
          ? tb.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0);
      return db_.compareTo(da);
    });
    return out;
  }

  @override
  Future<Result<Restaurant?>> getById(String id) async {
    try {
      final doc = await _restaurants.doc(id).get();
      return Result.success(RestaurantDto.fromMap(doc.id, doc.data()));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return const Result.success(null);
      return Result.failure(mapFirestoreError(e));
    } catch (e) {
      return Result.failure(mapFirestoreError(e));
    }
  }

  @override
  Future<Result<Restaurant?>> getBySlug(String slug) async {
    try {
      final docs = await _discoverableDocs(limit: 40);
      for (final d in docs) {
        if (d.data()['slug'] == slug) {
          return Result.success(RestaurantDto.fromMap(d.id, d.data()));
        }
      }
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirestoreError(e));
    }
  }

  @override
  Future<Result<List<Restaurant>>> searchByName(
    String query, {
    int limit = 20,
  }) async {
    final prefix = TextNormalizer.normalize(query);
    if (prefix.isEmpty) return const Result.success([]);
    try {
      // Prefijo sobre discoverables (sin exigir indice name+status).
      final docs = await _discoverableDocs(limit: 80);
      final hits = <Restaurant>[];
      for (final d in docs) {
        final r = RestaurantDto.fromMap(d.id, d.data());
        if (r == null) continue;
        if (r.normalizedName.startsWith(prefix) ||
            r.name.toLowerCase().startsWith(query.trim().toLowerCase())) {
          hits.add(r);
          if (hits.length >= limit) break;
        }
      }
      return Result.success(hits);
    } catch (e) {
      return Result.failure(mapFirestoreError(e));
    }
  }

  @override
  Future<Result<RestaurantPage>> getRestaurantsPage({
    int limit = 20,
    String? cursor,
    String? city,
    String? categoryId,
  }) async {
    try {
      // Pedimos de mas para paginar en cliente tras merge status/isActive.
      final docs = await _discoverableDocs(
        limit: limit + 20,
        city: city,
        categoryId: categoryId,
        orderByCreatedAt: true,
      );

      var start = 0;
      if (cursor != null && cursor.isNotEmpty) {
        final idx = docs.indexWhere((d) => d.id == cursor);
        start = idx < 0 ? 0 : idx + 1;
      }
      final slice = docs.skip(start).take(limit + 1).toList();
      final hasMore = slice.length > limit;
      final page = hasMore ? slice.sublist(0, limit) : slice;
      final items = [
        for (final d in page)
          if (RestaurantDto.fromMap(d.id, d.data()) case final r?) r,
      ];
      return Result.success(
        RestaurantPage(
          items: items,
          nextCursor: hasMore && page.isNotEmpty ? page.last.id : null,
        ),
      );
    } catch (e) {
      return Result.failure(mapFirestoreError(e));
    }
  }

  @override
  Future<Result<List<Restaurant>>> searchRestaurants({
    required String query,
    int limit = 20,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const Result.success([]);

    final byName = await searchByName(q, limit: limit);
    final nameHits = byName.fold(
      onSuccess: (list) => list,
      onFailure: (_) => <Restaurant>[],
    );

    try {
      final cityLower = q.toLowerCase();
      final docs = await _discoverableDocs(limit: 80);
      final cityHits = <Restaurant>[];
      for (final d in docs) {
        final r = RestaurantDto.fromMap(d.id, d.data());
        if (r == null) continue;
        if (r.city.toLowerCase().startsWith(cityLower)) {
          cityHits.add(r);
        }
      }

      final seen = <String>{};
      final merged = <Restaurant>[];
      for (final r in [...nameHits, ...cityHits]) {
        if (seen.add(r.id)) merged.add(r);
        if (merged.length >= limit) break;
      }
      return Result.success(merged);
    } catch (_) {
      return Result.success(nameHits);
    }
  }

  @override
  Future<Result<String>> createRequest(CreateEstablishmentRequest request) async {
    try {
      final ref = _restaurants.doc();
      await ref.set(
        RestaurantDto.toCreateRequestMap(
          name: request.name,
          city: request.city,
          country: request.country,
          creatorUid: request.creatorUid,
          address: request.address,
          description: request.description,
          imageUrl: request.imageUrl,
          categoryIds: request.categoryIds,
          latitude: request.latitude,
          longitude: request.longitude,
        ),
      );
      return Result.success(ref.id);
    } catch (e) {
      return Result.failure(mapFirestoreError(e));
    }
  }

  @override
  Future<Result<List<Restaurant>>> listMine(String uid) async {
    try {
      // Sin orderBy: evita índice compuesto mientras se construye
      // (creatorUserId/ownerUserId + createdAt). Ordenamos en cliente.
      final byCreator = await _restaurants
          .where('creatorUserId', isEqualTo: uid)
          .limit(50)
          .get();
      final byOwner = await _restaurants
          .where('ownerUserId', isEqualTo: uid)
          .limit(50)
          .get();
      final seen = <String>{};
      final out = <Restaurant>[];
      for (final doc in [...byCreator.docs, ...byOwner.docs]) {
        if (!seen.add(doc.id)) continue;
        final r = RestaurantDto.fromMap(doc.id, doc.data());
        if (r != null) out.add(r);
      }
      out.sort((a, b) {
        final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });
      return Result.success(out);
    } catch (e) {
      return Result.failure(mapFirestoreError(e));
    }
  }

  @override
  Future<Result<RestaurantPage>> listByStatus(
    EstablishmentStatus status, {
    int limit = 20,
    String? cursor,
  }) async {
    try {
      // Sin orderBy mientras el índice status+createdAt termina de construir.
      Query<Map<String, dynamic>> q = _restaurants
          .where('status', isEqualTo: status.name)
          .limit(limit + 1);
      if (cursor != null && cursor.isNotEmpty) {
        final c = await _restaurants.doc(cursor).get();
        if (c.exists) q = q.startAfterDocument(c);
      }
      final snap = await q.get();
      final parsed = <Restaurant>[
        for (final d in snap.docs)
          if (RestaurantDto.fromMap(d.id, d.data()) case final r?) r,
      ];
      parsed.sort((a, b) {
        final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });
      final hasMore = parsed.length > limit;
      final items = hasMore ? parsed.sublist(0, limit) : parsed;
      return Result.success(
        RestaurantPage(
          items: items,
          nextCursor: hasMore && items.isNotEmpty ? items.last.id : null,
        ),
      );
    } catch (e) {
      return Result.failure(mapFirestoreError(e));
    }
  }

  @override
  Future<Result<void>> updateOwnerFields({
    required String id,
    required String ownerUid,
    required OwnerEstablishmentUpdate update,
  }) async {
    try {
      final doc = await _restaurants.doc(id).get();
      if (!doc.exists) {
        return const Result.failure(
          UnexpectedFailure('Establecimiento no encontrado'),
        );
      }
      final data = doc.data()!;
      if (data['ownerUserId'] != ownerUid) {
        return const Result.failure(
          UnexpectedFailure('Solo el dueno puede editar'),
        );
      }
      await _restaurants.doc(id).update(
            RestaurantDto.toOwnerUpdateMap(
              name: update.name,
              city: update.city,
              country: update.country,
              address: update.address,
              description: update.description,
              imageUrl: update.imageUrl,
              logoUrl: update.logoUrl,
              categoryIds: update.categoryIds,
              latitude: update.latitude,
              longitude: update.longitude,
              phone: update.phone,
              whatsapp: update.whatsapp,
              websiteUrl: update.websiteUrl,
              instagramUrl: update.instagramUrl,
              facebookUrl: update.facebookUrl,
              tiktokUrl: update.tiktokUrl,
              galleryUrls: update.galleryUrls,
              videoUrls: update.videoUrls,
            ),
          );
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirestoreError(e));
    }
  }

  @override
  Future<Result<List<Restaurant>>> findPossibleDuplicates(
    String nameLower,
    String city,
  ) async {
    final normalized = nameLower.trim().toLowerCase();
    final c = city.trim();
    if (normalized.isEmpty || c.isEmpty) {
      return const Result.success([]);
    }
    try {
      final snap = await _restaurants
          .where('normalizedName', isEqualTo: normalized)
          .where('city', isEqualTo: c)
          .limit(10)
          .get();
      return Result.success(
        [
          for (final d in snap.docs)
            if (RestaurantDto.fromMap(d.id, d.data()) case final r?) r,
        ],
      );
    } catch (e) {
      return Result.failure(mapFirestoreError(e));
    }
  }
}
