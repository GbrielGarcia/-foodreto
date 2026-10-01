import 'unit_type.dart';

/// Categoría de comida (`categories/{slug}`).
class FoodCategory {
  const FoodCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.icon,
    required this.defaultUnit,
    required this.order,
    this.isActive = true,
    this.isSystemCategory = true,
    this.rankingEligible = true,
    this.createdAt,
  });

  final String id;
  final String name;

  /// Identificador en URLs (`/category/alitas`). Coincide con el id del documento.
  final String slug;

  /// Emoji que representa la categoría.
  final String icon;
  final UnitType defaultUnit;
  final int order;
  final bool isActive;

  /// Creada por FoodReto (no por un usuario).
  final bool isSystemCategory;

  /// Si sus resultados pueden entrar en rankings públicos.
  final bool rankingEligible;
  final DateTime? createdAt;
}
