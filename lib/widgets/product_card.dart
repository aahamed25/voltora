import 'package:flutter/material.dart';

import '../core/auth_gate.dart';
import '../core/theme.dart';
import '../models/product.dart';
import '../state/app_state.dart';
import '../pages/product_detail_page.dart';
import 'product_info.dart';
import 'product_image.dart';

class ProductGrid extends StatelessWidget {
  final List<Product> items;
  final bool scrollable;
  final bool compactImages;
  const ProductGrid(
    this.items, {
    super.key,
    this.scrollable = false,
    this.compactImages = false,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = compactImages
          ? ((constraints.maxWidth - 18) / 130).floor().clamp(2, 6).toInt()
          : 2;
      return GridView.builder(
        shrinkWrap: !scrollable,
        physics: scrollable ? null : const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 16,
          crossAxisSpacing: 14,
          childAspectRatio: 0.6,
        ),
        itemBuilder: (_, i) =>
            ProductCard(items[i], compactImage: compactImages),
      );
    },
  );
}

class ProductCard extends StatelessWidget {
  final Product p;
  final bool compactImage;
  const ProductCard(this.p, {super.key, this.compactImage = false});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: appState,
    builder: (context, _) => GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductDetailPage(p)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Align(
              alignment: compactImage
                  ? Alignment.bottomCenter
                  : Alignment.center,
              child: FractionallySizedBox(
                widthFactor: compactImage ? 0.72 : 1,
                heightFactor: compactImage ? 0.72 : 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: kGris,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: compactImage
                              ? Center(
                                  child: FractionallySizedBox(
                                    widthFactor: 0.65,
                                    heightFactor: 0.65,
                                    child: ProductImage(
                                      p,
                                      fit: BoxFit.contain,
                                      iconSize: 48,
                                    ),
                                  ),
                                )
                              : ProductImage(p, iconSize: 70),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: GestureDetector(
                          onTap: () => requireLogin(
                            context,
                            message: 'Connecte-toi pour ajouter un article aux favoris.',
                            onAuthenticated: () async =>
                                appState.toggleFav(p.id),
                          ),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              appState.isFav(p.id)
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 16,
                              color: appState.isFav(p.id)
                                  ? Colors.red
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      if (p.stock == 0)
                        const Positioned(
                          left: 8,
                          bottom: 8,
                          child: Text(
                            'Rupture',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          RatingChip(p),
          const SizedBox(height: 6),
          Text(
            p.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          PriceRow(p),
        ],
      ),
    ),
  );
}
