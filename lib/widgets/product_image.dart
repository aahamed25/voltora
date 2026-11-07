import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/product.dart';
import '../services/api_client.dart';

class ProductImage extends StatelessWidget {
  final Product product;
  final BoxFit fit;
  final double iconSize;
  final String? imageUrl;

  const ProductImage(
    this.product, {
    super.key,
    this.fit = BoxFit.cover,
    this.iconSize = 48,
    this.imageUrl,
  });

  Widget _fallback() => Center(
    child: Icon(
      product.icon,
      size: iconSize,
      color: product.stock == 0 ? Colors.grey : kViolet,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final source = imageUrl ?? product.imageUrl;
    if (source == null || source.isEmpty) return _fallback();

    return Image.network(
      apiClient.resolveImageUrl(source),
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return _fallback();
      },
      errorBuilder: (context, error, stackTrace) => _fallback(),
    );
  }
}
