import 'package:flutter_test/flutter_test.dart';
import 'package:voltora/data/catalog.dart';
import 'package:voltora/models/cart_item_key.dart';
import 'package:voltora/models/order.dart';
import 'package:voltora/models/product.dart';
import 'package:voltora/models/product_notification.dart';
import 'package:voltora/services/api_client.dart';

void main() {
  test('preserves product notification read state when serialized', () {
    final notification = ProductNotification(
      productId: 12,
      productName: 'Nouveau casque',
      createdAt: DateTime.utc(2026, 11, 7, 12),
      isRead: true,
    );

    final restored = ProductNotification.fromJson(notification.toJson());

    expect(restored.productId, 12);
    expect(restored.productName, 'Nouveau casque');
    expect(restored.createdAt, notification.createdAt);
    expect(restored.isRead, isTrue);
  });

  test('keeps cart entries separate for each selected color', () {
    final cart = <CartItemKey, int>{
      const CartItemKey(1, color: 'Noir'): 1,
      const CartItemKey(1, color: 'Blanc'): 2,
    };

    expect(cart, hasLength(2));
  });

  test('matches mobile API categories with the Smartphones category', () {
    expect(categoriesMatch('mobile', 'Smartphones'), isTrue);
    expect(categoriesMatch('Ordinateurs', 'ordinateurs'), isTrue);
    expect(categoriesMatch('Ordinateur', 'Ordinateurs'), isTrue);
    expect(categoriesMatch('Casques', 'Tablettes'), isFalse);
  });

  test('decodes MySQL decimal strings in products', () {
    final product = Product.fromJson({
      'id': '8',
      'name': 'Book Pro 14',
      'brand': 'Nova',
      'category': 'Ordinateurs',
      'description': 'Ordinateur portable',
      'price': '1499.00',
      'promo_price': '1399.00',
      'stock': '4',
      'rating': '4.70',
      'reviews': '201',
      'icon': 'laptop_mac',
      'image_url': null,
      'image_urls': [
        'https://example.com/front.jpg',
        'https://example.com/back.jpg',
      ],
      'color_stock': {'Noir': 3, 'Blanc': 0},
      'specs': {'RAM': '16 Go'},
    });

    expect(product.id, 8);
    expect(product.price, 1499);
    expect(product.promoPrice, 1399);
    expect(product.stock, 4);
    expect(product.rating, 4.7);
    expect(product.reviews, 201);
    expect(product.colorStock, {'Noir': 3, 'Blanc': 0});
    expect(product.galleryImageUrls, [
      'https://example.com/front.jpg',
      'https://example.com/back.jpg',
    ]);
  });

  test('uses the legacy image URL when no gallery is returned', () {
    final product = Product.fromJson({
      'id': '10',
      'name': 'Legacy product',
      'brand': 'Voltora',
      'category': 'Mobile',
      'description': 'Ancien produit à une photo.',
      'price': '99.00',
      'promo_price': null,
      'stock': '1',
      'rating': '0',
      'reviews': '0',
      'icon': 'devices',
      'image_url': 'https://example.com/legacy.jpg',
      'specs': <String, dynamic>{},
    });

    expect(product.galleryImageUrls, ['https://example.com/legacy.jpg']);
    expect(product.colorStock, isEmpty);
  });

  test('resolves uploaded photo paths against the API host', () {
    final client = ApiClient();
    addTearDown(client.dispose);

    expect(
      client.resolveImageUrl('/voltora/backend/public/uploads/photo.jpg'),
      'http://localhost/voltora/backend/public/uploads/photo.jpg',
    );
    expect(
      client.resolveImageUrl('https://example.com/photo.jpg'),
      'https://example.com/photo.jpg',
    );
  });

  test('decodes products with an empty specs list', () {
    final product = Product.fromJson({
      'id': '9',
      'name': 'Galaxy S26 Ultra',
      'brand': 'Samsung',
      'category': 'mobile',
      'description': 'Smartphone',
      'price': '925.00',
      'promo_price': '799.00',
      'stock': '10',
      'rating': '0.00',
      'reviews': '0',
      'icon': 'devices',
      'image_url': null,
      'specs': <dynamic>[],
    });

    expect(product.specs, isEmpty);
  });

  test('decodes MySQL decimal strings and timestamps in orders', () {
    final order = Order.fromJson({
      'number': 'VLT-20260621-ABC123',
      'total': '129.90',
      'item_count': '2',
      'created_at': '2026-06-21 12:15:00',
      'status': 'En préparation',
    });

    expect(order.total, 129.9);
    expect(order.itemCount, 2);
    expect(order.date, DateTime(2026, 6, 21, 12, 15));
  });
}
