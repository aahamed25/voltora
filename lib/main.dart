import 'dart:async';

import 'package:flutter/material.dart';
import 'app.dart';
import 'state/app_state.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await authService.init();
  runApp(const VoltoraApp());
  unawaited(appState.initialize());
  unawaited(authService.refreshAdminSetupStatus());
}
