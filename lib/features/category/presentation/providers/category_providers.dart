import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../data/repositories/firestore_category_repository.dart';
import '../../data/repositories/in_memory_category_repository.dart';
import '../../data/seed/dev_category_seed.dart';
import '../../domain/entities/food_category.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/usecases/category_usecases.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return switch (ref.watch(appConfigProvider).backendMode) {
    BackendMode.firebase => FirestoreCategoryRepository(
      ref.watch(firestoreProvider),
    ),
    BackendMode.local => InMemoryCategoryRepository(devCategorySeed),
  };
});

/// Catálogo de categorías activas. Se mantiene en memoria mientras la app
/// está abierta: cambia muy poco y se usa en varias pantallas.
final categoriesProvider = FutureProvider<List<FoodCategory>>((ref) async {
  final result = await GetCategories(ref.watch(categoryRepositoryProvider))();
  return result.fold(
    onSuccess: (categories) {
      debugPrint(
        'FoodReto: categoriesProvider → ${categories.length} categorías',
      );
      return categories;
    },
    onFailure: (failure) {
      debugPrint(
        'FoodReto: categoriesProvider error '
        '[${failure.code}] ${failure.message}',
      );
      throw failure;
    },
  );
});

/// Categoría por ID de documento, desde el catálogo en memoria (los retos
/// guardan `categoryId`). `null` si no está en el catálogo activo.
final categoryByIdProvider = Provider.autoDispose
    .family<AsyncValue<FoodCategory?>, String>((ref, id) {
      return ref
          .watch(categoriesProvider)
          .whenData((list) => list.where((c) => c.id == id).firstOrNull);
    });

/// Categoría por slug; `null` si no existe.
final categoryProvider = FutureProvider.autoDispose
    .family<FoodCategory?, String>((ref, slug) async {
      // Si el catálogo ya está cargado, evita una lectura extra.
      final cached = ref.read(categoriesProvider).value;
      if (cached != null) {
        for (final category in cached) {
          if (category.slug == slug) return category;
        }
      }
      final result = await GetCategoryBySlug(
        ref.watch(categoryRepositoryProvider),
      )(slug);
      return result.fold(
        onSuccess: (category) => category,
        onFailure: (failure) => throw failure,
      );
    });
