import 'package:flutter/material.dart';

import 'router.dart';

class ToungularApp extends StatelessWidget {
  const ToungularApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Toungular',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A4D6E),
        ),
      ),
      routerConfig: appRouter,
    );
  }
}
