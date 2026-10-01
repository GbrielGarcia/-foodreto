import '../../../../core/firebase/firestore_error_mapper.dart';
import '../../domain/entities/food_category.dart';
import '../../domain/entities/unit_type.dart';

abstract final class FoodCategoryDto {
  /// `null` si faltan campos obligatorios (documento mal formado).
  static FoodCategory? fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) return null;
    final name = data['name'];
    if (name is! String || name.trim().isEmpty) return null;
    final slug = data['slug'];
    final icon = data['icon'];
    final order = data['order'];
    return FoodCategory(
      id: id,
      name: name.trim(),
      slug: slug is String && slug.isNotEmpty ? slug : id,
      icon: icon is String && icon.isNotEmpty ? icon : '🍽️',
      defaultUnit: UnitType.fromId(data['defaultUnit']),
      order: order is num ? order.toInt() : 999,
      isActive: data['isActive'] != false,
      // Por seguridad, solo cuenta como sistema/ranking si lo dice explícitamente.
      isSystemCategory: data['isSystemCategory'] == true,
      rankingEligible: data['rankingEligible'] == true,
      createdAt: readTimestamp(data['createdAt']),
    );
  }
}
