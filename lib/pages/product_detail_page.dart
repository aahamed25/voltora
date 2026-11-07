import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/auth_gate.dart';
import '../core/format.dart';
import '../core/navigation.dart';
import '../models/cart_item_key.dart';
import '../models/product.dart';
import '../state/app_state.dart';
import '../widgets/product_info.dart';
import '../widgets/confirm_order.dart';
import '../widgets/product_image.dart';

class ProductDetailPage extends StatefulWidget {
  final Product p;
  const ProductDetailPage(this.p, {super.key});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  bool expanded = false;
  String? _selectedColor;
  int _selectedImageIndex = 0;
  late final PageController _galleryController = PageController();

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  Color _colorForName(String name) {
    final normalized = name
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a');

    if (normalized.contains('noir') || normalized.contains('black')) {
      return const Color(0xFF262626);
    }
    if (normalized.contains('blanc') || normalized.contains('white')) {
      return const Color(0xFFF8FAFC);
    }
    if (normalized.contains('argent') || normalized.contains('silver')) {
      return const Color(0xFFD8DADD);
    }
    if (normalized.contains('gris') || normalized.contains('gray')) {
      return const Color(0xFF777777);
    }
    if (normalized.contains('bordeaux') || normalized.contains('wine')) {
      return const Color(0xFF651E2B);
    }
    if (normalized.contains('rouge') || normalized.contains('red')) {
      return const Color(0xFFC62828);
    }
    if (normalized.contains('bleu') || normalized.contains('blue')) {
      return const Color(0xFF3977B8);
    }
    if (normalized.contains('vert') || normalized.contains('green')) {
      return const Color(0xFF38835A);
    }
    if (normalized.contains('jaune') || normalized.contains('gold')) {
      return const Color(0xFFE5B84B);
    }
    if (normalized.contains('rose') || normalized.contains('pink')) {
      return const Color(0xFFE58CA3);
    }
    if (normalized.contains('violet') || normalized.contains('purple')) {
      return const Color(0xFF7861A8);
    }
    if (normalized.contains('orange')) return const Color(0xFFE8751A);
    if (normalized.contains('marron') || normalized.contains('brown')) {
      return const Color(0xFF795548);
    }
    if (normalized.contains('beige')) return const Color(0xFFD9C6A5);
    return const Color(0xFF9AA3AD);
  }

  Widget _colorSwatch(String colorName, int stock) {
    final selected = _selectedColor == colorName;
    final available = stock > 0;
    final swatchColor = _colorForName(colorName);

    return Tooltip(
      message: available ? colorName : '$colorName - indisponible',
      child: Semantics(
        button: true,
        selected: selected,
        label: available ? colorName : '$colorName - indisponible',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            if (!available) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cette couleur n’est plus disponible.'),
                ),
              );
              return;
            }
            setState(() => _selectedColor = colorName);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? const Color(0xFF1677FF) : Colors.transparent,
                width: 2,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: swatchColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: swatchColor.computeLuminance() > 0.75
                          ? const Color(0xFFD1D5DB)
                          : Colors.transparent,
                    ),
                  ),
                ),
                if (!available)
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0x88FFFFFF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, size: 20, color: Colors.black54),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _gallery(Product product, {required bool verticalThumbnails}) {
    final imageUrls = product.galleryImageUrls;
    final mainImage = Container(
      decoration: BoxDecoration(
        color: kGris,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: PageView.builder(
        controller: _galleryController,
        itemCount: imageUrls.isEmpty ? 1 : imageUrls.length,
        onPageChanged: (index) => setState(() => _selectedImageIndex = index),
        itemBuilder: (context, index) => ProductImage(
          product,
          imageUrl: imageUrls.isEmpty ? null : imageUrls[index],
          fit: BoxFit.contain,
          iconSize: 130,
        ),
      ),
    );

    final thumbnails = imageUrls.length > 1
        ? SizedBox(
            height: 68,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: imageUrls.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => GestureDetector(
                onTap: () {
                  _galleryController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                  );
                },
                child: Container(
                  width: 68,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: index == _selectedImageIndex
                          ? kViolet
                          : Colors.transparent,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ProductImage(
                    product,
                    imageUrl: imageUrls[index],
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: verticalThumbnails ? 360 : 280,
          width: double.infinity,
          child: mainImage,
        ),
        if (imageUrls.length > 1) ...[const SizedBox(height: 10), thumbnails],
      ],
    );
  }

  Widget _productDetails(Product product, bool inStock) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RatingChip(product),
      const SizedBox(height: 8),
      Text(
        product.name,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 6),
      if (MediaQuery.sizeOf(context).width < 1000) PriceRow(product, size: 18),
      const SizedBox(height: 4),
      Text(
        inStock
            ? (product.stock <= 5
                  ? 'Plus que ${product.stock} en stock'
                  : 'En stock')
            : 'Rupture de stock',
        style: TextStyle(
          fontSize: 12,
          color: inStock ? Colors.green[700] : Colors.red,
        ),
      ),
      if (product.colorStock.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(
          _selectedColor == null
              ? 'Coloris - Choisissez votre couleur'
              : 'Coloris - $_selectedColor',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in product.colorStock.entries)
              _colorSwatch(entry.key, entry.value),
          ],
        ),
        if (_selectedColor == null)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Choisis une couleur pour continuer.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ),
      ],
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Divider(),
      ),
      const Text(
        'Description',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 6),
      Text(
        product.description,
        maxLines: expanded ? null : 3,
        overflow: expanded ? null : TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.black54, height: 1.4),
      ),
      GestureDetector(
        onTap: () => setState(() => expanded = !expanded),
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            expanded ? 'Réduire' : 'Lire la suite',
            style: const TextStyle(color: kViolet),
          ),
        ),
      ),
      if (expanded) ...[
        const SizedBox(height: 16),
        const Text(
          'Caractéristiques',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        ...product.specs.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    entry.key,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                Expanded(child: Text(entry.value)),
              ],
            ),
          ),
        ),
      ],
    ],
  );

  Widget _purchaseActions(
    BuildContext context,
    Product product,
    bool inStock, {
    required bool vertical,
    required String? color,
  }) {
    final addButton = OutlinedButton(
      onPressed: inStock
          ? () => requireLogin(
              context,
              message: 'Connecte-toi pour ajouter un article au panier.',
              onAuthenticated: () async {
                await appState.addToCart(product, color: color);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ajouté au panier')),
                  );
                }
              },
            )
          : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: kViolet,
        side: const BorderSide(color: kViolet),
        shape: const StadiumBorder(),
        minimumSize: const Size.fromHeight(52),
      ),
      child: const Text('Ajouter au panier'),
    );
    final buyButton = FilledButton(
      onPressed: inStock
          ? () => confirmOrder(context, {
              CartItemKey(product.id, color: color): 1,
            }, product.finalPrice)
          : null,
      style: FilledButton.styleFrom(
        backgroundColor: kViolet,
        shape: const StadiumBorder(),
        minimumSize: const Size.fromHeight(52),
      ),
      child: const Text('Acheter'),
    );

    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PriceRow(product, size: 22),
          const SizedBox(height: 12),
          addButton,
          const SizedBox(height: 10),
          buyButton,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: addButton),
        const SizedBox(width: 12),
        Expanded(child: buyButton),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final inStock = p.stock > 0;
    final canPurchase =
        inStock && (p.colorStock.isEmpty || _selectedColor != null);
    final isWide = MediaQuery.sizeOf(context).width >= 1000;
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              icon: Icon(
                appState.isFav(p.id) ? Icons.favorite : Icons.favorite_border,
                color: appState.isFav(p.id) ? Colors.red : Colors.black87,
              ),
              onPressed: () => requireLogin(
                context,
                message: 'Connecte-toi pour ajouter un article aux favoris.',
                onAuthenticated: () async => appState.toggleFav(p.id),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.shopping_bag_outlined),
              onPressed: () => goToCart(context),
            ),
          ],
        ),
        body: isWide
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1600),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: _gallery(p, verticalThumbnails: true),
                        ),
                        const SizedBox(width: 28),
                        Expanded(flex: 5, child: _productDetails(p, inStock)),
                        const SizedBox(width: 28),
                        SizedBox(
                          width: 250,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: _purchaseActions(
                                context,
                                p,
                                canPurchase,
                                vertical: true,
                                color: _selectedColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  _gallery(p, verticalThumbnails: false),
                  const SizedBox(height: 16),
                  _productDetails(p, inStock),
                ],
              ),
        bottomNavigationBar: isWide
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: _purchaseActions(
                    context,
                    p,
                    canPurchase,
                    vertical: false,
                    color: _selectedColor,
                  ),
                ),
              ),
      ),
    );
  }
}
