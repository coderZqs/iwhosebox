import 'package:flutter/foundation.dart';
import 'product.dart';

/// Cart Model - manages cart items locally
class CartItem {
  final Product product;
  final ProductVariant variant;
  int quantity;

  CartItem({
    required this.product,
    required this.variant,
    this.quantity = 1,
  });

  double get totalPrice => variant.price * quantity;

  Map<String, dynamic> toJson() => {
        'productId': product.id,
        'variantId': variant.id,
        'title': product.title,
        'variantTitle': variant.title,
        'price': variant.price,
        'quantity': quantity,
        'imageUrl': product.featuredImage ?? variant.image,
      };
}

/// Cart state managed by Provider
class CartModel extends ChangeNotifier {
  final List<CartItem> _items = [];
  
  List<CartItem> get items => List.unmodifiable(_items);
  
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  
  double get subtotal => _items.fold(0.0, (sum, item) => sum + item.totalPrice);

  void addItem(Product product, ProductVariant variant, {int quantity = 1}) {
    final index = _items.indexWhere((item) => item.variant.id == variant.id);
    if (index >= 0) {
      _items[index].quantity += quantity;
    } else {
      _items.add(CartItem(
        product: product,
        variant: variant,
        quantity: quantity,
      ));
    }
    notifyListeners();
  }

  void removeItem(String variantId) {
    _items.removeWhere((item) => item.variant.id == variantId);
    notifyListeners();
  }

  void updateQuantity(String variantId, int quantity) {
    final index = _items.indexWhere((item) => item.variant.id == variantId);
    if (index >= 0) {
      if (quantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index].quantity = quantity;
      }
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
