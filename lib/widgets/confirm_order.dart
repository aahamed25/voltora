import 'package:flutter/material.dart';

import '../core/auth_gate.dart';
import '../pages/checkout_page.dart';
import '../models/cart_item_key.dart';
import '../services/auth_service.dart';

Future<void> confirmOrder(
  BuildContext context,
  Map<CartItemKey, int> items,
  double total,
) async {
  if (items.isEmpty) return;
  if (!authService.isLoggedIn) {
    await requireLogin(
      context,
      message: 'Connecte-toi pour passer une commande.',
      onAuthenticated: () => confirmOrder(context, items, total),
    );
    return;
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CheckoutAddressPage(items: items, total: total),
    ),
  );
}
