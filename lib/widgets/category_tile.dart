import 'package:flutter/material.dart';
import '../core/theme.dart';

class CategoryTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg, fg;
  final VoidCallback onTap;
  const CategoryTile(this.label, this.icon, this.bg, this.fg, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                  color: bg, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, size: 38, color: fg == Colors.black87 ? kViolet : fg),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ]),
      );
}
