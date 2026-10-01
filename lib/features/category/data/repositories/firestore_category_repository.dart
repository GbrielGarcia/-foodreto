import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/error/result.dart';
import '../../../../core/firebase/firestore_collections.dart';
import '../../../../core/firebase/firestore_error_mapper.dart';
import '../../domain/entities/food_category.dart';
import '../../domain/repositories/category_repository.dart';
import '../models/food_category_dto.dart';

class FirestoreCategoryRepository implements CategoryRepository {
  FirestoreCategoryRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _categories =>
      _db.collection(FirestoreCollections.categories);

  @override
  Future<Result<List<FoodCategory>>> getCategories() async {
    try {
      // Catálogo pequeño: se filtra `isActive` en cliente para no requerir
      // un índice compuesto.
      final snapshot = await _categories.orderBy('order').get();
      final categories = snapshot.docs
          .map((doc) => FoodCategoryDto.fromMap(doc.id, doc.data()))
          .whereType<FoodCategory>()
          .where((c) => c.isActive)
          .toList();
      final projectLabel = _projectLabel();
      if (categories.isEmpty) {
        debugPrint(
          'Firestore: categories vacío '
          '(${snapshot.docs.length} docs leídos; '
          'project=$projectLabel). '
          'Si esperabas el catálogo, ejecuta el seed contra este mismo '
          'proyecto Firebase (no contra el Emulator Suite).',
        );
      } else {
        debugPrint(
          'Firestore: categories → ${categories.length} activas '
          '(project=$projectLabel)',
        );
      }
      return Result.success(categories);
    } catch (e, st) {
      debugPrint('Firestore: getCategories falló: $e\n$st');
      return Result.failure(mapFirestoreError(e));
    }
  }

  String _projectLabel() {
    try {
      return _db.app.options.projectId;
    } catch (_) {
      return 'unknown';
    }
  }

  @override
  Future<Result<FoodCategory?>> getCategoryBySlug(String slug) async {
    try {
      // Convención: el id del documento es el slug.
      final doc = await _categories.doc(slug).get();
      var category = FoodCategoryDto.fromMap(doc.id, doc.data());
      if (category == null) {
        final query = await _categories
            .where('slug', isEqualTo: slug)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          final match = query.docs.first;
          category = FoodCategoryDto.fromMap(match.id, match.data());
        }
      }
      return Result.success(category?.isActive ?? false ? category : null);
    } catch (e, st) {
      debugPrint('Firestore: getCategoryBySlug($slug) falló: $e\n$st');
      return Result.failure(mapFirestoreError(e));
    }
  }
}
