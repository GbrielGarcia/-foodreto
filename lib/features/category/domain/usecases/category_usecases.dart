import '../../../../core/error/result.dart';
import '../entities/food_category.dart';
import '../repositories/category_repository.dart';

class GetCategories {
  const GetCategories(this._repository);
  final CategoryRepository _repository;

  Future<Result<List<FoodCategory>>> call() => _repository.getCategories();
}

class GetCategoryBySlug {
  const GetCategoryBySlug(this._repository);
  final CategoryRepository _repository;

  Future<Result<FoodCategory?>> call(String slug) =>
      _repository.getCategoryBySlug(slug.trim().toLowerCase());
}
