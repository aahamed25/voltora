import 'package:flutter/material.dart';

import '../pages/login_page.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

Future<void> runApiAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } on ApiException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }
}

Future<void> requireLogin(
  BuildContext context, {
  required String message,
  required Future<void> Function() onAuthenticated,
}) async {
  try {
    if (authService.isLoggedIn) {
      await runApiAction(context, onAuthenticated);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LoginPage(
          prompt: message,
          onAuthenticated: () => runApiAction(context, onAuthenticated),
        ),
      ),
    );
  } on ApiException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }
}
