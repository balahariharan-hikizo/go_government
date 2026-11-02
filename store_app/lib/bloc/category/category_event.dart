abstract class CategoryEvent {}

class LoadStoreCategoriesEvent extends CategoryEvent {
  final String storeId;
  final bool activeOnly;

  LoadStoreCategoriesEvent(this.storeId, {this.activeOnly = false});
}

class CreateCategoryEvent extends CategoryEvent {
  final String storeId;
  final String name;
  final String parentCategoryId;
  final String description;
  final String icon;
  final String image;
  final int displayOrder;
  final bool isActive;

  CreateCategoryEvent({
    required this.storeId,
    required this.name,
    this.parentCategoryId = '',
    this.description = '',
    this.icon = '',
    this.image = '',
    this.displayOrder = 0,
    this.isActive = true,
  });
}

class UpdateCategoryEvent extends CategoryEvent {
  final String categoryId;
  final String? name;
  final String? description;
  final String? icon;
  final String? image;
  final int? displayOrder;
  final bool? isActive;

  UpdateCategoryEvent({
    required this.categoryId,
    this.name,
    this.description,
    this.icon,
    this.image,
    this.displayOrder,
    this.isActive,
  });
}

class ToggleCategoryActiveEvent extends CategoryEvent {
  final String categoryId;
  final bool isActive;

  ToggleCategoryActiveEvent({
    required this.categoryId,
    required this.isActive,
  });
}

class DeleteCategoryEvent extends CategoryEvent {
  final String categoryId;

  DeleteCategoryEvent(this.categoryId);
}

class ToggleCategoryExpansionEvent extends CategoryEvent {
  final String categoryId;

  ToggleCategoryExpansionEvent(this.categoryId);
}

