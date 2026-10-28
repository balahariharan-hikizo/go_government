abstract class CartEvent {}

class AddToCartEvent extends CartEvent {
  final String productId;
  final Map<String, dynamic> details;
  AddToCartEvent(this.productId, this.details);
}

class RemoveFromCartEvent extends CartEvent {
  final String productId;
  RemoveFromCartEvent(this.productId);
}

class UpdateQuantityEvent extends CartEvent {
  final String productId;
  final int quantity;
  final Map<String, dynamic>? details;
  UpdateQuantityEvent(this.productId, this.quantity, {this.details});
}

class ClearCartEvent extends CartEvent {}

class ToggleFavoriteEvent extends CartEvent {
  final String productId;
  final Map<String, dynamic> details;
  ToggleFavoriteEvent(this.productId, this.details);
}

class FetchCartAndWishlistEvent extends CartEvent {}

class ResetCartAndWishlistEvent extends CartEvent {}


