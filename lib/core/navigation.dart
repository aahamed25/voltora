import 'package:flutter/material.dart';
import '../state/app_state.dart';

void goToCart(BuildContext context) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  appState.setTab(3);
}
