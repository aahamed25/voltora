import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/catalog.dart' show categoryIcon;
import '../models/product_notification.dart';
import '../state/app_state.dart';
import '../widgets/category_tile.dart';
import '../widgets/product_card.dart';
import 'notifications_page.dart';
import 'product_list_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Widget _circle(IconData icon, {VoidCallback? onTap, int badgeCount = 0}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: badgeCount > 0
              ? Badge(
                  label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
                  child: Icon(icon, color: kViolet, size: 20),
                )
              : Icon(icon, color: kViolet, size: 20),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final deals = appState.products
        .where((product) => product.promoPrice != null)
        .toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          decoration: const BoxDecoration(
            color: kViolet,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _circle(Icons.menu),
                  const SizedBox(width: 12),
                  const Icon(Icons.bolt, color: Colors.white, size: 24),
                  const Text(
                    'Voltora',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  ListenableBuilder(
                    listenable: appState,
                    builder: (context, _) => _circle(
                      Icons.notifications_none,
                      badgeCount: appState.unreadNotificationsCount,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsPage(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _circle(
                    Icons.shopping_bag_outlined,
                    onTap: () => appState.setTab(3),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Découvrez une nouvelle ère du shopping électronique',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  height: 1.25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                textInputAction: TextInputAction.search,
                onSubmitted: (q) => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProductListPage(title: 'Recherche', query: q),
                  ),
                ),
                decoration: InputDecoration(
                  hintText: 'Rechercher',
                  hintStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.12),
                  contentPadding: EdgeInsets.zero,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Text(
            'Toutes les catégories',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  for (final category in appState.categories)
                    CategoryTile(
                      category,
                      categoryIcon(category),
                      kGris,
                      Colors.black87,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductListPage(
                              title: category,
                              category: category,
                            ),
                          ),
                        );
                      },
                    ),
                  CategoryTile(
                    'Plus',
                    Icons.apps,
                    const Color(0xFFE9E4FF),
                    kViolet,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProductListPage(
                            title: 'Catalogue',
                            compactImages: true,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            children: [
              const Text(
                'Meilleures offres',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProductListPage(
                      title: 'Meilleures offres',
                      onlyDeals: true,
                    ),
                  ),
                ),
                child: const Text(
                  'Voir tout',
                  style: TextStyle(color: kViolet, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 285,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: deals.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) =>
                SizedBox(width: 175, child: ProductCard(deals[i])),
          ),
        ),
      ],
    );
  }
}
