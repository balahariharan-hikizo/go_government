import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../hive/hive_service.dart';
import '../../network/cart_wishlist_api_service.dart';
import 'cart_event.dart';
import 'cart_state.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  static final CartBloc instance = CartBloc._();

  CartBloc._() : super(CartState.initial()) {
    on<FetchCartAndWishlistEvent>((event, emit) async {
      try {
        final cartData = await CartWishlistApiService.fetchCart();
        final wishlistData = await CartWishlistApiService.fetchWishlist();

        final updatedCart = Map<String, int>.from(state.cartItems);
        final updatedDetails = Map<String, Map<String, dynamic>>.from(state.productDetails);
        final updatedFavorites = Set<String>.from(state.favoriteIds);

        bool cartChanged = false;
        bool wishlistChanged = false;

        if (cartData != null && cartData['items'] is List) {
          final items = cartData['items'] as List;
          if (items.isNotEmpty) {
            updatedCart.clear();
            for (final it in items) {
              final pid = (it['productId'] ?? '').toString();
              var vid = (it['variantId'] ?? '').toString();
              final unit = (it['unit'] ?? '').toString().trim();
              final prod = it['product'] is Map
                  ? Map<String, dynamic>.from(it['product'])
                  : <String, dynamic>{'id': pid};

              // Auto-resolve vid if backend saved it empty but product has variants
              if (vid.isEmpty && prod['variants'] is List && (prod['variants'] as List).isNotEmpty) {
                final variants = prod['variants'] as List;
                if (unit.isNotEmpty) {
                  final match = variants.firstWhere(
                    (v) => (v is Map && (v['unit']?.toString().trim().toLowerCase() ?? '') == unit.toLowerCase()),
                    orElse: () => null,
                  );
                  if (match is Map && match['variantId'] != null) {
                    vid = match['variantId'].toString();
                  }
                }
                if (vid.isEmpty && variants.first is Map && variants.first['variantId'] != null) {
                  vid = variants.first['variantId'].toString();
                }
              }

              final itemKey = vid.isNotEmpty ? '$pid:$vid' : pid;
              final qty = (it['quantity'] as num?)?.toInt() ?? 1;
              prod['id'] = itemKey;
              prod['productId'] = pid;
              prod['variantId'] = vid;
              if (it['unit'] != null && it['unit'].toString().isNotEmpty) {
                prod['unit'] = it['unit'];
              }
              if (it['price'] != null) {
                prod['price'] = it['price'];
              }
              if (itemKey.isNotEmpty) {
                updatedCart[itemKey] = qty;
                updatedDetails[itemKey] = {...updatedDetails[itemKey] ?? {}, ...prod};
              }
            }
            cartChanged = true;
          } else if (state.cartItems.isNotEmpty) {
            // Local has items but server cart is empty: sync local up to server
            unawaited(CartWishlistApiService.syncCart(
              cartItems: state.cartItems,
              productDetails: state.productDetails,
            ));
          }
        }

        if (wishlistData != null && wishlistData['favoriteIds'] is List) {
          final fids = (wishlistData['favoriteIds'] as List).map((e) => e.toString()).toSet();
          if (fids.isNotEmpty) {
            updatedFavorites.clear();
            updatedFavorites.addAll(fids);
            if (wishlistData['items'] is List) {
              for (final it in (wishlistData['items'] as List)) {
                final pid = (it['productId'] ?? '').toString();
                final prod = it['product'] is Map
                    ? Map<String, dynamic>.from(it['product'])
                    : <String, dynamic>{'id': pid};
                if (pid.isNotEmpty) {
                  updatedDetails[pid] = {...updatedDetails[pid] ?? {}, ...prod, 'id': pid};
                }
              }
            }
            wishlistChanged = true;
          } else if (state.favoriteIds.isNotEmpty) {
            // Local has favorites but server is empty: sync local up to server
            unawaited(CartWishlistApiService.syncWishlist(
              favoriteIds: state.favoriteIds,
              productDetails: state.productDetails,
            ));
          }
        }

        if (cartChanged || wishlistChanged) {
          HiveService.saveCartItems(updatedCart);
          HiveService.saveProductDetails(updatedDetails);
          HiveService.saveFavoriteIds(updatedFavorites);

          emit(state.copyWith(
            cartItems: updatedCart,
            productDetails: updatedDetails,
            favoriteIds: updatedFavorites,
          ));
        }
      } catch (e) {
        // Graceful fallback to cached state if network fails
      }
    });

    on<AddToCartEvent>((event, emit) {
      final updatedCart = Map<String, int>.from(state.cartItems);
      final updatedDetails = Map<String, Map<String, dynamic>>.from(state.productDetails);

      updatedCart[event.productId] = (updatedCart[event.productId] ?? 0) + 1;
      updatedDetails[event.productId] = {
        ...updatedDetails[event.productId] ?? {},
        ...event.details,
        'id': event.productId,
      };

      HiveService.saveCartItems(updatedCart);
      HiveService.saveProductDetails(updatedDetails);

      emit(state.copyWith(
        cartItems: updatedCart,
        productDetails: updatedDetails,
      ));

      // Asynchronously update backend
      unawaited(CartWishlistApiService.addToCart(
        productId: event.productId,
        product: updatedDetails[event.productId] ?? event.details,
      ));
    });

    on<RemoveFromCartEvent>((event, emit) {
      final updatedCart = Map<String, int>.from(state.cartItems);
      final updatedDetails = Map<String, Map<String, dynamic>>.from(state.productDetails);

      if (updatedCart.containsKey(event.productId)) {
        final currentQty = updatedCart[event.productId]!;
        if (currentQty > 1) {
          updatedCart[event.productId] = currentQty - 1;
        } else {
          updatedCart.remove(event.productId);
          updatedDetails.remove(event.productId);
        }
      }

      HiveService.saveCartItems(updatedCart);
      HiveService.saveProductDetails(updatedDetails);

      emit(state.copyWith(
        cartItems: updatedCart,
        productDetails: updatedDetails,
      ));

      // Asynchronously update backend
      final remainingQty = updatedCart[event.productId] ?? 0;
      if (remainingQty > 0) {
        unawaited(CartWishlistApiService.updateQuantity(
          productId: event.productId,
          quantity: remainingQty,
        ));
      } else {
        unawaited(CartWishlistApiService.removeFromCart(
          productId: event.productId,
        ));
      }
    });

    on<UpdateQuantityEvent>((event, emit) {
      final updatedCart = Map<String, int>.from(state.cartItems);
      final updatedDetails = Map<String, Map<String, dynamic>>.from(state.productDetails);

      if (event.quantity > 0) {
        updatedCart[event.productId] = event.quantity;
        if (event.details != null && event.details!.isNotEmpty) {
          updatedDetails[event.productId] = {
            ...updatedDetails[event.productId] ?? {},
            ...event.details!,
            'id': event.productId,
          };
        } else if (!updatedDetails.containsKey(event.productId)) {
          updatedDetails[event.productId] = {'id': event.productId};
        }
      } else {
        updatedCart.remove(event.productId);
        updatedDetails.remove(event.productId);
      }

      HiveService.saveCartItems(updatedCart);
      HiveService.saveProductDetails(updatedDetails);

      emit(state.copyWith(
        cartItems: updatedCart,
        productDetails: updatedDetails,
      ));

      // Asynchronously update backend
      unawaited(CartWishlistApiService.updateQuantity(
        productId: event.productId,
        quantity: event.quantity,
        product: updatedDetails[event.productId],
      ));
    });

    on<ClearCartEvent>((event, emit) {
      HiveService.clearCart();
      emit(state.copyWith(
        cartItems: {},
        productDetails: {},
      ));

      // Asynchronously clear backend
      unawaited(CartWishlistApiService.clearCart());
    });

    on<ToggleFavoriteEvent>((event, emit) {
      final updatedFavorites = Set<String>.from(state.favoriteIds);
      final updatedDetails = Map<String, Map<String, dynamic>>.from(state.productDetails);

      if (updatedFavorites.contains(event.productId)) {
        updatedFavorites.remove(event.productId);
      } else {
        updatedFavorites.add(event.productId);
        updatedDetails[event.productId] = event.details;
      }

      HiveService.saveFavoriteIds(updatedFavorites);
      HiveService.saveProductDetails(updatedDetails);

      emit(state.copyWith(
        favoriteIds: updatedFavorites,
        productDetails: updatedDetails,
      ));

      // Asynchronously update backend
      unawaited(CartWishlistApiService.toggleWishlist(
        productId: event.productId,
        product: event.details,
      ));
    });

    on<ResetCartAndWishlistEvent>((event, emit) {
      emit(CartState(
        cartItems: {},
        productDetails: {},
        favoriteIds: {},
      ));
    });

    // Initial fetch and sync from backend on startup (now that all handlers are registered)
    add(FetchCartAndWishlistEvent());
  }
}

