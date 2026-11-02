import '../../model/category_model.dart';

abstract class CategoryState {}

class CategoryInitial extends CategoryState {}

class CategoryLoading extends CategoryState {}

class CategoryLoaded extends CategoryState {
  final List<CategoryModel> categories;
  final Set<String> expandedCategoryIds;
  final String? activeCategoryId;
  final String? filterQuery;

  CategoryLoaded({
    required this.categories,
    this.expandedCategoryIds = const {},
    this.activeCategoryId,
    this.filterQuery,
  });

  List<CategoryModel> get rootCategories =>
      categories.where((c) => c.level == 0 || c.parentCategoryId.isEmpty).toList();

  List<CategoryModel> getChildren(String parentId) =>
      categories.where((c) => c.parentCategoryId == parentId).toList();

  CategoryLoaded copyWith({
    List<CategoryModel> Function()? categories,
    Set<String> Function()? expandedCategoryIds,
    String? Function()? activeCategoryId,
    String? Function()? filterQuery,
  }) {
    return CategoryLoaded(
      categories: categories != null ? categories() : this.categories,
      expandedCategoryIds: expandedCategoryIds != null ? expandedCategoryIds() : this.expandedCategoryIds,
      activeCategoryId: activeCategoryId != null ? activeCategoryId() : this.activeCategoryId,
      filterQuery: filterQuery != null ? filterQuery() : this.filterQuery,
    );
  }
}

class CategoryOperationSuccess extends CategoryState {
  final String message;
  final CategoryModel? category;

  CategoryOperationSuccess(this.message, {this.category});
}

class CategoryError extends CategoryState {
  final String message;

  CategoryError(this.message);
}

