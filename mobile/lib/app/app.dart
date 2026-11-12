import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/toungular_theme.dart';
import 'router.dart';

class ToungularApp extends ConsumerWidget {
  const ToungularApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Toungular',
      debugShowCheckedModeBanner: false,
      theme: ToungularTheme.light,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
