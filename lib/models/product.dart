import 'package:flutter/material.dart';

class Product {
  final int id;
  final String name, brand, description, category;
  final double price;
  final double? promoPrice;
  final int stock;
  final double rating;
  final int reviews;
  final IconData icon;
  final String? imageUrl;
  final List<String> imageUrls;
  final Map<String, String> specs;
  final Map<String, int> colorStock;

  const Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.description,
    required this.category,
    required this.price,
    this.promoPrice,
    required this.stock,
    required this.rating,
    required this.reviews,
    required this.icon,
    this.imageUrl,
    this.imageUrls = const [],
    this.specs = const {},
    this.colorStock = const {},
  });

  double get finalPrice => promoPrice ?? price;
  List<String> get galleryImageUrls =>
      imageUrls.isNotEmpty ? imageUrls : [?imageUrl];

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawSpecs = json['specs'];
    final specs = switch (rawSpecs) {
      Map<String, dynamic> values => values,
      List<dynamic> values when values.isEmpty => const <String, dynamic>{},
      null => const <String, dynamic>{},
      _ => throw const FormatException(
        'Les caractéristiques du produit doivent être un objet.',
      ),
    };
    final rawImageUrls = json['image_urls'];
    final imageUrls = switch (rawImageUrls) {
      List<dynamic> values => values.map((value) => value as String).toList(),
      null => <String>[],
      _ => throw const FormatException(
        'Les images du produit doivent être une liste.',
      ),
    };
    final imageUrl = json['image_url'] as String?;
    if (imageUrls.isEmpty && imageUrl != null && imageUrl.isNotEmpty) {
      imageUrls.add(imageUrl);
    }
    final rawColorStock = json['color_stock'];
    final colorStock = switch (rawColorStock) {
      Map<String, dynamic> values => values.map(
        (color, quantity) =>
            MapEntry(color, int.parse(quantity.toString())),
      ),
      null => const <String, int>{},
      _ => throw const FormatException(
        'Le stock par couleur doit être un objet.',
      ),
    };

    return Product(
      id: int.parse(json['id'].toString()),
      name: json['name'] as String,
      brand: json['brand'] as String,
      category: json['category'] as String,
      description: json['description'] as String,
      price: double.parse(json['price'].toString()),
      promoPrice: json['promo_price'] == null
          ? null
          : double.parse(json['promo_price'].toString()),
      stock: int.parse(json['stock'].toString()),
      rating: double.tryParse(json['rating']?.toString() ?? '') ?? 0,
      reviews: int.tryParse(json['reviews']?.toString() ?? '') ?? 0,
      icon: productIcon(json['icon'] as String?),
      imageUrl: imageUrls.isEmpty ? imageUrl : imageUrls.first,
      imageUrls: imageUrls,
      colorStock: colorStock,
      specs: specs.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }
}

IconData productIcon(String? name) => switch (name) {
  'smartphone' => Icons.smartphone,
  'phone_android' => Icons.phone_android,
  'laptop_mac' => Icons.laptop_mac,
  'tablet_mac' => Icons.tablet_mac,
  'headphones' => Icons.headphones,
  'earbuds' => Icons.earbuds,
  'speaker' => Icons.speaker,
  'watch' => Icons.watch,
  _ => Icons.devices,
};
