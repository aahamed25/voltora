import 'package:flutter/material.dart';

import '../models/product.dart';

const allCategories = [
  'Smartphones',
  'Ordinateurs',
  'Tablettes',
  'Casques',
  'Enceintes',
  'Montres',
];

IconData categoryIcon(String category) => switch (category
    .trim()
    .toLowerCase()) {
  'smartphone' || 'smartphones' || 'mobile' || 'mobiles' => Icons.smartphone,
  'ordinateur' || 'ordinateurs' => Icons.laptop_mac,
  'tablette' || 'tablettes' => Icons.tablet_mac,
  'casque' || 'casques' => Icons.headphones,
  'enceinte' || 'enceintes' => Icons.speaker,
  'montre' || 'montres' => Icons.watch,
  _ => Icons.category_outlined,
};

bool categoriesMatch(String first, String second) {
  String canonical(String category) {
    final normalized = category.trim().toLowerCase();
    return switch (normalized) {
      'mobile' || 'mobiles' || 'smartphone' || 'smartphones' => 'smartphones',
      'ordinateur' || 'ordinateurs' => 'ordinateurs',
      'tablette' || 'tablettes' => 'tablettes',
      'casque' || 'casques' => 'casques',
      'enceinte' || 'enceintes' => 'enceintes',
      'montre' || 'montres' => 'montres',
      _ => normalized,
    };
  }

  return canonical(first) == canonical(second);
}

const products = <Product>[
  Product(
    id: 1,
    name: 'Nova X Pro 256 Go, 5G',
    brand: 'Nova',
    category: 'Smartphones',
    description: 'Écran AMOLED 6,7" 120 Hz, triple capteur photo 50 Mpx et charge rapide 67 W. Un smartphone pensé pour durer toute la journée et au-delà.',
    price: 899,
    promoPrice: 749,
    stock: 12,
    rating: 4.6,
    reviews: 128,
    icon: Icons.smartphone,
    imageUrl: 'https://images.unsplash.com/photo-1512499617640-c74ae3a79d37?auto=format&fit=max&w=1200&q=90',
    specs: {
      'Écran': '6,7" AMOLED',
      'Stockage': '256 Go',
      'Batterie': '5000 mAh',
    },
  ),
  Product(
    id: 2,
    name: 'Pulse Mini 128 Go',
    brand: 'Pulse',
    category: 'Smartphones',
    description: 'Compact, léger et performant pour un usage quotidien, avec un écran OLED lumineux.',
    price: 499,
    stock: 5,
    rating: 4.2,
    reviews: 64,
    icon: Icons.phone_android,
    imageUrl: 'https://images.unsplash.com/photo-1598327105666-5b89351aff97?auto=format&fit=max&w=1200&q=90',
    specs: {'Écran': '6,1" OLED', 'Stockage': '128 Go', 'Batterie': '4200 mAh'},
  ),
  Product(
    id: 3,
    name: 'AirBeat Studio – Blanc',
    brand: 'Beatz',
    category: 'Casques',
    description: 'Casque sans fil à réduction de bruit active, 40 h d\'autonomie et micro haute définition pour les appels.',
    price: 249,
    promoPrice: 189,
    stock: 20,
    rating: 4.8,
    reviews: 310,
    icon: Icons.headphones,
    imageUrl: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=max&w=1200&q=90',
    specs: {'Autonomie': '40 h', 'Bluetooth': '5.3', 'Poids': '250 g'},
  ),
  Product(
    id: 4,
    name: 'Buds Lite',
    brand: 'Beatz',
    category: 'Casques',
    description: 'Écouteurs intra-auriculaires avec boîtier de charge compact.',
    price: 79,
    stock: 0,
    rating: 4.0,
    reviews: 87,
    icon: Icons.earbuds,
    imageUrl: 'https://images.unsplash.com/photo-1606220945770-b5b6c2c55bf1?auto=format&fit=max&w=1200&q=90',
    specs: {'Autonomie': '8 h', 'Bluetooth': '5.2', 'Étanchéité': 'IPX4'},
  ),
  Product(
    id: 5,
    name: 'Boom Speaker 360',
    brand: 'Boom',
    category: 'Enceintes',
    description:
        'Enceinte portable étanche au son 360° et à la basse profonde.',
    price: 129,
    promoPrice: 99,
    stock: 9,
    rating: 4.5,
    reviews: 142,
    icon: Icons.speaker,
    imageUrl: 'https://images.unsplash.com/photo-1608043152269-423dbba4e7e1?auto=format&fit=max&w=1200&q=90',
    specs: {'Autonomie': '20 h', 'Puissance': '30 W', 'Étanchéité': 'IP67'},
  ),
  Product(
    id: 6,
    name: 'Chrono Ultra 47 mm, LTE',
    brand: 'Chrono',
    category: 'Montres',
    description: 'Cadran en verre saphir et boîtier en titane, conçu pour résister à tout. Étanche 10 ATM avec GPS double fréquence et suivi sportif avancé.',
    price: 600,
    promoPrice: 580,
    stock: 15,
    rating: 4.9,
    reviews: 1800,
    icon: Icons.watch,
    imageUrl: 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?auto=format&fit=max&w=1200&q=90',
    specs: {
      'Boîtier': '47 mm titane',
      'GPS': 'Double fréquence',
      'Autonomie': '3 jours',
    },
  ),
  Product(
    id: 7,
    name: 'Tab Air 11" – Gris sidéral',
    brand: 'Nova',
    category: 'Tablettes',
    description: 'Tablette 11" idéale pour le travail et le divertissement.',
    price: 780,
    promoPrice: 750,
    stock: 7,
    rating: 4.4,
    reviews: 120,
    icon: Icons.tablet_mac,
    imageUrl: 'https://images.unsplash.com/photo-1544244015-0df4b3ffc6b0?auto=format&fit=max&w=1200&q=90',
    specs: {'Écran': '11" LCD', 'Stockage': '128 Go', 'RAM': '8 Go'},
  ),
  Product(
    id: 8,
    name: 'Book Pro 14 – M3',
    brand: 'Nova',
    category: 'Ordinateurs',
    description: 'Ordinateur portable fin et puissant avec écran Retina 14" et 18 h d\'autonomie.',
    price: 1499,
    promoPrice: 1399,
    stock: 4,
    rating: 4.7,
    reviews: 201,
    icon: Icons.laptop_mac,
    imageUrl: 'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?auto=format&fit=max&w=1200&q=90',
    specs: {'Écran': '14" Retina', 'RAM': '16 Go', 'SSD': '512 Go'},
  ),
];
