import 'package:flutter/material.dart';

import '../core/theme/toungular_theme.dart';
import 'router.dart';

class ToungularApp extends StatelessWidget {
  const ToungularApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Toungular',
      debugShowCheckedModeBanner: false,
      theme: ToungularTheme.light,
      routerConfig: appRouter,
    );
  }
}
