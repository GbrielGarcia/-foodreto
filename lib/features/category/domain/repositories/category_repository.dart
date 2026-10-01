import '../../../../core/error/result.dart';
import '../entities/food_category.dart';

abstract interface class CategoryRepository {
  /// Categorías activas ordenadas por `order`.
  Future<Result<List<FoodCategory>>> getCategories();

  /// `null` si no existe o está inactiva.
  Future<Result<FoodCategory?>> getCategoryBySlug(String slug);
}
