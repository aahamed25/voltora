import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/format.dart';
import '../models/product.dart';

class RatingChip extends StatelessWidget {
  final Product p;
  const RatingChip(this.p, {super.key});

  @override
  Widget build(BuildContext context) {
    final r = p.reviews >= 1000
        ? '${(p.reviews / 1000).toStringAsFixed(1)}K'
        : '${p.reviews}';
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: kJaune, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          const Icon(Icons.star, size: 12, color: Colors.amber),
          const SizedBox(width: 2),
          Text(p.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 11)),
        ]),
      ),
      const SizedBox(width: 6),
      Flexible(
          child: Text('$r avis',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.grey))),
    ]);
  }
}

class PriceRow extends StatelessWidget {
  final Product p;
  final double size;
  const PriceRow(this.p, {super.key, this.size = 13});

  @override
  Widget build(BuildContext context) => Row(children: [
        Text(euro(p.finalPrice),
            style: TextStyle(
                color: kViolet, fontWeight: FontWeight.w600, fontSize: size)),
        if (p.promoPrice != null) ...[
          const SizedBox(width: 6),
          Text(euro(p.price),
              style: TextStyle(
                  color: Colors.grey,
                  fontSize: size - 1,
                  decoration: TextDecoration.lineThrough)),
        ],
      ]);
}
