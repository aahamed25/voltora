import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../state/app_state.dart';
import 'home_page.dart';
import 'favorites_page.dart';
import 'orders_page.dart';
import 'cart_page.dart';
import 'profile_page.dart';

class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    const pages = [
      HomePage(),
      FavoritesPage(),
      OrdersPage(),
      CartPage(),
      ProfilePage(),
    ];
    const items = <(IconData, String)>[
      (Icons.home_outlined, 'Accueil'),
      (Icons.favorite_border, 'Favoris'),
      (Icons.receipt_long_outlined, 'Commandes'),
      (Icons.shopping_bag_outlined, 'Panier'),
      (Icons.person_outline, 'Profil'),
    ];
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (appState.apiError != null)
                MaterialBanner(
                  content: Text(appState.apiError!),
                  leading: const Icon(Icons.cloud_off),
                  actions: [
                    TextButton(
                      onPressed: appState.dismissApiError,
                      child: const Text('Fermer'),
                    ),
                  ],
                ),
              Expanded(child: pages[appState.tab]),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: EdgeInsets.fromLTRB(
            12,
            10,
            12,
            10 + MediaQuery.of(context).padding.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 12,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(items.length, (i) {
              final selected = appState.tab == i;
              Widget icon = Icon(
                items[i].$1,
                color: selected ? Colors.white : Colors.grey,
                size: 24,
              );
              if (i == 3 && appState.cartCount > 0) {
                icon = Badge(label: Text('${appState.cartCount}'), child: icon);
              }
              return GestureDetector(
                onTap: () => appState.setTab(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: selected ? 16 : 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? kViolet : Colors.transparent,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      icon,
                      if (selected) ...[
                        const SizedBox(width: 6),
                        Text(
                          items[i].$2,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
