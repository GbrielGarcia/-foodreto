import 'dart:convert';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodreto/core/error/result.dart';
import 'package:foodreto/features/category/data/models/food_category_dto.dart';
import 'package:foodreto/features/category/data/repositories/firestore_category_repository.dart';
import 'package:foodreto/features/category/data/repositories/in_memory_category_repository.dart';
import 'package:foodreto/features/category/data/seed/dev_category_seed.dart';
import 'package:foodreto/features/category/domain/entities/food_category.dart';
import 'package:foodreto/features/category/domain/entities/unit_type.dart';

void main() {
  group('FoodCategoryDto', () {
    test('parsea un documento completo', () {
      final category = FoodCategoryDto.fromMap('alitas', {
        'name': 'Alitas',
        'slug': 'alitas',
        'icon': '🍗',
        'defaultUnit': 'units',
        'isActive': true,
        'order': 1,
        'isSystemCategory': true,
        'rankingEligible': true,
      })!;
      expect(category.name, 'Alitas');
      expect(category.icon, '🍗');
      expect(category.defaultUnit, UnitType.units);
      expect(category.order, 1);
      expect(category.rankingEligible, isTrue);
    });

    test('valores por defecto seguros', () {
      final category = FoodCategoryDto.fromMap('x', {'name': 'Ceviche'})!;
      expect(category.slug, 'x');
      expect(category.icon, '🍽️');
      expect(category.defaultUnit, UnitType.units);
      expect(category.isActive, isTrue);
      expect(
        category.rankingEligible,
        isFalse,
        reason: 'no entra en rankings si no se indica',
      );
      expect(category.isSystemCategory, isFalse);
    });

    test('unidad desconocida cae a unidades', () {
      expect(
        FoodCategoryDto.fromMap('x', {
          'name': 'X',
          'defaultUnit': 'kg',
        })!.defaultUnit,
        UnitType.units,
      );
    });

    test('documento sin nombre es inválido', () {
      expect(FoodCategoryDto.fromMap('x', {'icon': '🍕'}), isNull);
      expect(FoodCategoryDto.fromMap('x', null), isNull);
    });
  });

  group('FirestoreCategoryRepository', () {
    late FakeFirebaseFirestore db;
    late FirestoreCategoryRepository repository;

    setUp(() async {
      db = FakeFirebaseFirestore();
      repository = FirestoreCategoryRepository(db);
      await db.doc('categories/sushi').set({
        'name': 'Sushi', 'slug': 'sushi', 'icon': '🍣', //
        'defaultUnit': 'pieces', 'order': 2, 'isActive': true,
      });
      await db.doc('categories/alitas').set({
        'name': 'Alitas', 'slug': 'alitas', 'icon': '🍗', //
        'defaultUnit': 'units', 'order': 1, 'isActive': true,
      });
      await db.doc('categories/oculta').set({
        'name': 'Oculta',
        'slug': 'oculta',
        'order': 3,
        'isActive': false,
      });
      await db.doc('categories/auto-id-123').set({
        'name': 'Hot Dogs',
        'slug': 'hot-dogs',
        'order': 4,
        'isActive': true,
      });
    });

    test('devuelve activas ordenadas', () async {
      final result = await repository.getCategories();
      final names = (result as Success<List<FoodCategory>>).value
          .map((c) => c.name)
          .toList();
      expect(names, ['Alitas', 'Sushi', 'Hot Dogs']);
    });

    test('busca por slug (id del documento o campo slug)', () async {
      final sushi = await repository.getCategoryBySlug('sushi');
      final hotDogs = await repository.getCategoryBySlug('hot-dogs');
      expect(
        (sushi as Success<FoodCategory?>).value?.defaultUnit,
        UnitType.pieces,
      );
      expect((hotDogs as Success<FoodCategory?>).value?.name, 'Hot Dogs');
    });

    test('inactiva o inexistente devuelve null', () async {
      expect(
        (await repository.getCategoryBySlug('oculta') as Success).value,
        isNull,
      );
      expect(
        (await repository.getCategoryBySlug('nada') as Success).value,
        isNull,
      );
    });
  });

  test('InMemoryCategoryRepository filtra inactivas', () async {
    final repository = InMemoryCategoryRepository(const [
      FoodCategory(
        id: 'b',
        name: 'B',
        slug: 'b',
        icon: 'b',
        defaultUnit: UnitType.units,
        order: 2,
      ),
      FoodCategory(
        id: 'a',
        name: 'A',
        slug: 'a',
        icon: 'a',
        defaultUnit: UnitType.units,
        order: 1,
      ),
      FoodCategory(
        id: 'c',
        name: 'C',
        slug: 'c',
        icon: 'c',
        defaultUnit: UnitType.units,
        order: 0,
        isActive: false,
      ),
    ]);
    final result = await repository.getCategories();
    expect((result as Success<List<FoodCategory>>).value.map((c) => c.id), [
      'a',
      'b',
    ]);
  });

  test('el seed de desarrollo coincide con tool/seed/categories.json', () {
    final json =
        jsonDecode(File('tool/seed/categories.json').readAsStringSync())
            as List<dynamic>;
    expect(json.length, devCategorySeed.length);
    for (var i = 0; i < json.length; i++) {
      final entry = json[i] as Map<String, dynamic>;
      final seed = devCategorySeed[i];
      expect(entry['slug'], seed.slug);
      expect(entry['name'], seed.name);
      expect(entry['icon'], seed.icon);
      expect(entry['defaultUnit'], seed.defaultUnit.id);
      expect(entry['order'], seed.order);
      expect(seed.id, seed.slug, reason: 'el id del documento es el slug');
    }
    expect(
      devCategorySeed.map((c) => c.name),
      containsAll([
        'Alitas', 'Sushi', 'Pizza', 'Hamburguesas', 'Tacos', //
        'Pollo', 'Hot Dogs', 'Postres', 'Donas', 'Parrillada',
        'Cerveza', 'Cócteles', 'Tequila', 'Vino', 'Shots',
        'Ron', 'Whisky', 'Margaritas', 'Mojitos',
      ]),
    );
    expect(
      devCategorySeed.singleWhere((c) => c.slug == 'pollo').icon,
      '🐔',
      reason: 'Pollo debe usar exactamente 🐔',
    );
  });

  /// Refleja `tool/seed/seed_categories.mjs`: doc id = slug, upsert por
  /// updateMask (sin crear documentos nuevos en re-ejecuciones).
  test('seed de categorías: 3 ejecuciones no duplican documentos', () async {
    final json =
        jsonDecode(File('tool/seed/categories.json').readAsStringSync())
            as List<dynamic>;
    final db = FakeFirebaseFirestore();
    final repository = FirestoreCategoryRepository(db);

    Future<void> runSeedOnce() async {
      for (final raw in json) {
        final entry = raw as Map<String, dynamic>;
        final slug = entry['slug'] as String;
        final ref = db.doc('categories/$slug');
        final existing = await ref.get();
        await ref.set({
          'name': entry['name'],
          'slug': slug,
          'icon': entry['icon'],
          'defaultUnit': entry['defaultUnit'],
          'order': entry['order'],
          'isActive': true,
          'isSystemCategory': true,
          'rankingEligible': true,
          if (!existing.exists) 'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }
    }

    await runSeedOnce();
    await runSeedOnce();
    await runSeedOnce();

    final docs = await db.collection('categories').get();
    expect(docs.docs.length, 40);
    expect(docs.docs.map((d) => d.id).toSet().length, 40);
    expect((await db.doc('categories/pollo').get()).data()?['icon'], '🐔');

    final result = await repository.getCategories();
    final categories = (result as Success<List<FoodCategory>>).value;
    expect(categories.length, 40);
    expect(categories.first.slug, 'alitas');
    expect(categories.last.slug, 'refrescos');
    expect(categories.singleWhere((c) => c.slug == 'pollo').icon, '🐔');
    expect(categories.any((c) => c.slug == 'cerveza'), isTrue);
  });
}
