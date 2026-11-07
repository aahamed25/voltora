import 'package:flutter/material.dart';

class PageTitle extends StatelessWidget {
  final String t;
  const PageTitle(this.t);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(t,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
      );
}
