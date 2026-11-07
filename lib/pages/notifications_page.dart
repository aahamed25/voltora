import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/product.dart';
import '../models/product_notification.dart';
import '../state/app_state.dart';
import 'product_detail_page.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  Product? _findProduct(int id) {
    for (final product in appState.products) {
      if (product.id == id) return product;
    }
    return null;
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');
    return '$day/$month/${localDate.year} à $hour:$minute';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        ListenableBuilder(
          listenable: appState,
          builder: (context, _) => appState.unreadNotificationsCount == 0
              ? const SizedBox.shrink()
              : TextButton(
                  onPressed: appState.markAllNotificationsRead,
                  child: const Text('Tout lire'),
                ),
        ),
      ],
    ),
    body: ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        if (appState.notifications.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications_none, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text('Aucune notification pour le moment.'),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: appState.notifications.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
          itemBuilder: (context, index) {
            final notification = appState.notifications[index];
            return _NotificationTile(
              notification: notification,
              dateLabel: _formatDate(notification.createdAt),
              onTap: () async {
                await appState.markNotificationRead(notification.productId);
                if (!context.mounted) return;
                final product = _findProduct(notification.productId);
                if (product == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cet article n’est plus disponible.'),
                    ),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProductDetailPage(product)),
                );
              },
            );
          },
        );
      },
    ),
  );
}

class _NotificationTile extends StatelessWidget {
  final ProductNotification notification;
  final String dateLabel;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.dateLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: CircleAvatar(
      backgroundColor: notification.isRead
          ? kGris
          : kViolet.withValues(alpha: 0.1),
      child: Icon(
        Icons.inventory_2_outlined,
        color: notification.isRead ? Colors.grey : kViolet,
      ),
    ),
    title: Text(
      'Nouvel article disponible',
      style: TextStyle(
        fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w700,
      ),
    ),
    subtitle: Text('${notification.productName}\n$dateLabel'),
    isThreeLine: true,
    trailing: notification.isRead
        ? null
        : const Icon(Icons.circle, size: 10, color: kViolet),
  );
}
