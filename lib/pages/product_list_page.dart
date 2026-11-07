import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/navigation.dart';
import '../data/catalog.dart' show categoriesMatch;
import '../state/app_state.dart';

import '../widgets/product_card.dart';

class ProductListPage extends StatefulWidget {
  final String title;
  final String? category;
  final bool onlyDeals;
  final bool compactImages;
  final String query;
  const ProductListPage({
    super.key,
    required this.title,
    this.category,
    this.onlyDeals = false,
    this.compactImages = false,
    this.query = '',
  });

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  late String query = widget.query;
  late String? category = widget.category;
  late bool searching = widget.query.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final q = query.toLowerCase();
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final list = appState.products.where((product) {
          return (category == null ||
                  categoriesMatch(product.category, category!)) &&
              (!widget.onlyDeals || product.promoPrice != null) &&
              (q.isEmpty ||
                  product.name.toLowerCase().contains(q) ||
                  product.brand.toLowerCase().contains(q) ||
                  product.category.toLowerCase().contains(q));
        }).toList();

        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: Text(
              widget.title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => setState(() => searching = !searching),
              ),
              IconButton(
                icon: const Icon(Icons.shopping_bag_outlined),
                onPressed: () => goToCart(context),
              ),
            ],
          ),
          body: Column(
            children: [
              if (searching)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: TextField(
                    autofocus: true,
                    controller: TextEditingController(text: query)
                      ..selection = TextSelection.collapsed(
                        offset: query.length,
                      ),
                    onChanged: (value) => setState(() => query = value),
                    decoration: InputDecoration(
                      hintText: 'Nom, marque ou catégorie',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: kGris,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              if (widget.category == null && !widget.onlyDeals)
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final categoryName in appState.categories)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(categoryName),
                            selected: category == categoryName,
                            selectedColor: kViolet,
                            labelStyle: TextStyle(
                              color: category == categoryName
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                            showCheckmark: false,
                            onSelected: (selected) => setState(
                              () => category = selected ? categoryName : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text('Aucun produit trouvé.'))
                    : ProductGrid(
                        list,
                        scrollable: true,
                        compactImages:
                            widget.category != null || widget.compactImages,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
