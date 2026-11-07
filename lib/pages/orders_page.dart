import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/format.dart';
import '../state/app_state.dart';
import '../widgets/page_title.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: appState,
    builder: (context, _) => Column(
      children: [
        const PageTitle('Mes commandes'),
        Expanded(
          child: appState.orders.isEmpty
              ? const Center(child: Text('Aucune commande pour le moment.'))
              : ListView(
                  children: appState.orders
                      .map(
                        (order) => ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: kGris,
                            child: Icon(Icons.local_shipping, color: kViolet),
                          ),
                          title: Text(order.number),
                          subtitle: Text(
                            '${order.itemCount} article(s) · ${order.date.day}/${order.date.month}/${order.date.year}\n'
                            '${order.status}'
                            '${order.shippingAddress == null ? '' : '\nLivraison : ${order.shippingAddress}'}',
                          ),
                          isThreeLine: order.shippingAddress != null,
                          trailing: Text(
                            euro(order.total),
                            style: const TextStyle(
                              color: kViolet,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    ),
  );
}
