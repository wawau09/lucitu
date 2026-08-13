import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:placelist/models/menu_model.dart';

class CartItem {
  final MenuItem menuItem;
  final String selectedOptionText; // e.g. "HOT / 샷추가 (+500원)"
  final int unitPrice; // base price + options price
  final int quantity;

  CartItem({
    required this.menuItem,
    required this.selectedOptionText,
    required this.unitPrice,
    required this.quantity,
  });

  int get subtotal => unitPrice * quantity;

  CartItem copyWith({
    MenuItem? menuItem,
    String? selectedOptionText,
    int? unitPrice,
    int? quantity,
  }) {
    return CartItem(
      menuItem: menuItem ?? this.menuItem,
      selectedOptionText: selectedOptionText ?? this.selectedOptionText,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
    );
  }
}

class CartState {
  final String? storeId;
  final String? storeName;
  final List<CartItem> items;

  CartState({this.storeId, this.storeName, List<CartItem>? items})
      : items = items ?? [];

  int get totalAmount => items.fold(0, (sum, item) => sum + item.subtotal);
  int get totalCount => items.fold(0, (sum, item) => sum + item.quantity);
  bool get isEmpty => items.isEmpty;

  CartState copyWith({
    String? storeId,
    String? storeName,
    List<CartItem>? items,
  }) {
    return CartState(
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      items: items ?? this.items,
    );
  }
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(CartState());

  void addItem({
    required String storeId,
    required String storeName,
    required MenuItem menuItem,
    required String selectedOptionText,
    required int unitPrice,
    int quantity = 1,
  }) {
    // If cart has items from another store, clear cart first
    if (state.storeId != null && state.storeId != storeId) {
      state = CartState(storeId: storeId, storeName: storeName);
    }

    final currentItems = List<CartItem>.from(state.items);
    final existingIndex = currentItems.indexWhere(
      (item) =>
          item.menuItem.id == menuItem.id &&
          item.selectedOptionText == selectedOptionText,
    );

    if (existingIndex >= 0) {
      final existing = currentItems[existingIndex];
      currentItems[existingIndex] = existing.copyWith(
        quantity: existing.quantity + quantity,
      );
    } else {
      currentItems.add(
        CartItem(
          menuItem: menuItem,
          selectedOptionText: selectedOptionText,
          unitPrice: unitPrice,
          quantity: quantity,
        ),
      );
    }

    state = state.copyWith(
      storeId: storeId,
      storeName: storeName,
      items: currentItems,
    );
  }

  void updateQuantity(int index, int quantity) {
    if (index < 0 || index >= state.items.length) return;
    final currentItems = List<CartItem>.from(state.items);

    if (quantity <= 0) {
      currentItems.removeAt(index);
    } else {
      currentItems[index] = currentItems[index].copyWith(quantity: quantity);
    }

    if (currentItems.isEmpty) {
      state = CartState();
    } else {
      state = state.copyWith(items: currentItems);
    }
  }

  void removeItem(int index) {
    updateQuantity(index, 0);
  }

  void clearCart() {
    state = CartState();
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>(
  (ref) => CartNotifier(),
);
