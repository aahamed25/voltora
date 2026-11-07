import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../widgets/page_title.dart';
import '../widgets/product_card.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final favs = appState.products
        .where((product) => appState.isFav(product.id))
        .toList();
    return Column(children: [
      const PageTitle('Mes favoris'),
      Expanded(
        child: favs.isEmpty
            ? const Center(child: Text('Aucun favori pour le moment.'))
            : ProductGrid(favs, scrollable: true),
      ),
    ]);
  }
}
