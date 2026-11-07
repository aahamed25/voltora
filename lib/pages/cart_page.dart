import 'package:flutter/material.dart';

import '../core/auth_gate.dart';
import '../core/theme.dart';
import '../core/format.dart';
import '../state/app_state.dart';
import '../widgets/page_title.dart';
import '../widgets/confirm_order.dart';
import '../widgets/product_image.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: appState,
    builder: (context, _) {
      final entries = appState.cart.entries.toList();
      return Column(
        children: [
          const PageTitle('Mon panier'),
          Expanded(
            child: entries.isEmpty
                ? const Center(child: Text('Votre panier est vide.'))
                : ListView(
                    children: entries.map((entry) {
                      final key = entry.key;
                      final product = appState.byId(key.productId);
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: ProductImage(product, iconSize: 28),
                          ),
                        ),
                        title: Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          [
                            if (key.color != null) 'Couleur : ${key.color}',
                            euro(product.finalPrice),
                          ].join(' · '),
                          style: const TextStyle(color: kViolet),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => runApiAction(
                                context,
                                () => appState.decrement(key),
                              ),
                            ),
                            Text('${entry.value}'),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => requireLogin(
                                context,
                                message:
                                    'Connecte-toi pour modifier ton panier.',
                                onAuthenticated: () =>
                                    appState.addToCart(
                                      product,
                                      color: key.color,
                                    ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () => runApiAction(
                                context,
                                () => appState.remove(key),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          if (entries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 16)),
                      Text(
                        euro(appState.cartTotal),
                        style: const TextStyle(
                          fontSize: 20,
                          color: kViolet,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: kViolet,
                      shape: const StadiumBorder(),
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: () => confirmOrder(
                      context,
                      Map.of(appState.cart),
                      appState.cartTotal,
                    ),
                    child: const Text('Commander'),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}
