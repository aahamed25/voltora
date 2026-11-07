import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/catalog.dart' as catalog;
import '../models/order.dart';
import '../models/cart_item_key.dart';
import '../models/product.dart';
import '../models/product_notification.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  static const _notificationsKey = 'voltora_product_notifications';
  static const _lastProductIdKey = 'voltora_last_notified_product_id';

  final Set<int> favorites = {};
  final Map<CartItemKey, int> cart = {};
  final List<Order> orders = [];
  final List<ProductNotification> notifications = [];
  List<Product> products = List<Product>.of(catalog.products);
  List<String> categories = List<String>.of(catalog.allCategories);
  int tab = 0;
  String? apiError;
  int? _lastNotifiedProductId;
  Timer? _productPollingTimer;
  bool _notificationsLoaded = false;
  bool _refreshingProducts = false;

  int get unreadNotificationsCount =>
      notifications.where((notification) => !notification.isRead).length;

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    await _loadNotifications();
    try {
      await Future.wait([refreshProducts(), refreshCategories()]);
      if (authService.isLoggedIn) await loadUserData();
    } on ApiException catch (error) {
      apiError = error.message;
      notifyListeners();
    }
    _productPollingTimer ??= Timer.periodic(
      const Duration(seconds: 45),
      (_) => unawaited(_refreshProductsQuietly()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshProductsQuietly());
    }
  }

  Future<void> _loadNotifications() async {
    if (_notificationsLoaded) return;
    final preferences = await SharedPreferences.getInstance();
    _lastNotifiedProductId = preferences.getInt(_lastProductIdKey);
    final rawNotifications = preferences.getString(_notificationsKey);
    if (rawNotifications != null) {
      try {
        final decoded = jsonDecode(rawNotifications);
        if (decoded is List<dynamic>) {
          notifications.addAll(
            decoded.map(
              (item) =>
                  ProductNotification.fromJson(item as Map<String, dynamic>),
            ),
          );
        }
      } on FormatException {
        notifications.clear();
      }
    }
    _notificationsLoaded = true;
  }

  Future<void> _saveNotifications() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _notificationsKey,
      jsonEncode(
        notifications.map((notification) => notification.toJson()).toList(),
      ),
    );
    final lastProductId = _lastNotifiedProductId;
    if (lastProductId != null) {
      await preferences.setInt(_lastProductIdKey, lastProductId);
    }
  }

  Future<void> _updateProducts(List<Product> updatedProducts) async {
    products = updatedProducts;
    final previousLastId = _lastNotifiedProductId;
    final newestId = products.fold<int>(
      0,
      (newest, product) => product.id > newest ? product.id : newest,
    );

    if (previousLastId == null) {
      _lastNotifiedProductId = newestId;
      await _saveNotifications();
      return;
    }

    final existingIds = notifications
        .map((notification) => notification.productId)
        .toSet();
    final newProducts =
        products
            .where(
              (product) =>
                  product.id > previousLastId &&
                  !existingIds.contains(product.id),
            )
            .toList()
          ..sort((first, second) => first.id.compareTo(second.id));

    if (newProducts.isNotEmpty) {
      notifications.insertAll(
        0,
        newProducts.reversed.map(
          (product) => ProductNotification(
            productId: product.id,
            productName: product.name,
            createdAt: DateTime.now(),
          ),
        ),
      );
    }
    if (newestId > previousLastId) _lastNotifiedProductId = newestId;
    await _saveNotifications();
  }

  Future<void> _refreshProductsQuietly() async {
    try {
      await Future.wait([refreshProducts(), refreshCategories()]);
    } on ApiException {
      return;
    }
  }

  Future<void> markNotificationRead(int productId) async {
    final index = notifications.indexWhere(
      (notification) => notification.productId == productId,
    );
    if (index == -1 || notifications[index].isRead) return;
    notifications[index] = notifications[index].copyWith(isRead: true);
    notifyListeners();
    await _saveNotifications();
  }

  Future<void> markAllNotificationsRead() async {
    if (unreadNotificationsCount == 0) return;
    for (var index = 0; index < notifications.length; index++) {
      notifications[index] = notifications[index].copyWith(isRead: true);
    }
    notifyListeners();
    await _saveNotifications();
  }

  void dismissApiError() {
    apiError = null;
    notifyListeners();
  }

  void setApiError(String message) {
    apiError = message;
    notifyListeners();
  }

  void clearUserData() {
    favorites.clear();
    cart.clear();
    orders.clear();
    notifyListeners();
  }

  void setTab(int i) {
    tab = i;
    notifyListeners();
  }

  bool isFav(int id) => favorites.contains(id);

  Future<void> refreshProducts() async {
    if (_refreshingProducts) return;
    _refreshingProducts = true;
    try {
      final response = await apiClient.get('products');
      final data = response['products'] as List<dynamic>;
      await _updateProducts(
        data
            .map((item) => Product.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
      apiError = null;
      notifyListeners();
    } finally {
      _refreshingProducts = false;
    }
  }

  Future<void> refreshCategories() async {
    final response = await apiClient.get('categories');
    categories = (response['categories'] as List<dynamic>).cast<String>();
    notifyListeners();
  }

  Future<void> loadUserData() async {
    try {
      final results = await Future.wait([
        apiClient.get('favorites'),
        apiClient.get('cart'),
        apiClient.get('orders'),
        apiClient.get('products'),
      ]);

      favorites
        ..clear()
        ..addAll((results[0]['ids'] as List<dynamic>).map((id) => id as int));
      cart
        ..clear()
        ..addEntries(
          (results[1]['items'] as List<dynamic>).map((item) {
            final json = item as Map<String, dynamic>;
            return MapEntry(
              CartItemKey(
                (json['id'] as num).toInt(),
                color: ((json['color'] as String?)?.isEmpty ?? true)
                    ? null
                    : json['color'] as String,
              ),
              (json['quantity'] as num).toInt(),
            );
          }),
        );
      orders
        ..clear()
        ..addAll(
          (results[2]['orders'] as List<dynamic>).map(
            (order) => Order.fromJson(order as Map<String, dynamic>),
          ),
        );
      await _updateProducts(
        (results[3]['products'] as List<dynamic>)
            .map((item) => Product.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
      apiError = null;
    } on ApiException catch (error) {
      apiError = error.message;
    }
    notifyListeners();
  }

  Future<void> toggleFav(int id) async {
    final wasFavorite = favorites.contains(id);
    if (wasFavorite) {
      await apiClient.delete('favorites/$id');
      favorites.remove(id);
    } else {
      await apiClient.post('favorites/$id');
      favorites.add(id);
    }
    notifyListeners();
  }

  Future<void> addToCart(Product product, {String? color}) async {
    final key = CartItemKey(product.id, color: color);
    final quantity = (cart[key] ?? 0) + 1;
    await apiClient.put(
      'cart/${product.id}',
      body: {'quantity': quantity, 'color': color ?? ''},
    );
    cart[key] = quantity;
    notifyListeners();
  }

  Future<void> decrement(CartItemKey key) async {
    final quantity = cart[key] ?? 0;
    if (quantity <= 1) {
      await remove(key);
      return;
    }
    await apiClient.put(
      'cart/${key.productId}',
      body: {'quantity': quantity - 1, 'color': key.color ?? ''},
    );
    cart[key] = quantity - 1;
    notifyListeners();
  }

  Future<void> remove(CartItemKey key) async {
    final color = Uri.encodeQueryComponent(key.color ?? '');
    await apiClient.delete('cart/${key.productId}?color=$color');
    cart.remove(key);
    notifyListeners();
  }

  int get cartCount => cart.values.fold(0, (a, b) => a + b);

  double get cartTotal => cart.entries.fold(
    0.0,
    (sum, entry) => sum + byId(entry.key.productId).finalPrice * entry.value,
  );

  Product byId(int id) => products.firstWhere(
    (product) => product.id == id,
    orElse: () => catalog.products.firstWhere((product) => product.id == id),
  );

  Future<Order> placeOrder(
    Map<CartItemKey, int> items, {
    required Map<String, String> shippingAddress,
  }) async {
    final response = await apiClient.post(
      'orders',
      body: {
        'shipping': shippingAddress,
        'items': items.entries
            .map(
              (entry) => {
                'product_id': entry.key.productId,
                'color': entry.key.color ?? '',
                'quantity': entry.value,
              },
            )
            .toList(),
      },
    );
    final order = Order.fromJson(response['order'] as Map<String, dynamic>);
    for (final key in items.keys) {
      cart.remove(key);
    }
    orders.insert(0, order);
    try {
      await refreshProducts();
    } on ApiException catch (error) {
      apiError = error.message;
    }
    notifyListeners();
    return order;
  }
}

final appState = AppState();
