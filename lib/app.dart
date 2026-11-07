import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../pages/shell.dart';

class VoltoraApp extends StatelessWidget {
  const VoltoraApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Voltora',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: kViolet),
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              scrolledUnderElevation: 0),
        ),
        home: const SelectionArea(child: Shell()),
      );
}
