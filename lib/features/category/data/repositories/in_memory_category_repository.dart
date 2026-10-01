import '../../../../core/error/result.dart';
import '../../domain/entities/food_category.dart';
import '../../domain/repositories/category_repository.dart';

class InMemoryCategoryRepository implements CategoryRepository {
  InMemoryCategoryRepository(List<FoodCategory> categories)
    : _categories = List.of(categories);

  final List<FoodCategory> _categories;

  @override
  Future<Result<List<FoodCategory>>> getCategories() async {
    final active = _categories.where((c) => c.isActive).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return Result.success(active);
  }

  @override
  Future<Result<FoodCategory?>> getCategoryBySlug(String slug) async {
    for (final category in _categories) {
      if (category.slug == slug && category.isActive) {
        return Result.success(category);
      }
    }
    return const Result.success(null);
  }
}
