import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'shared/router/app_router.dart';
import 'shared/theme/app_theme.dart';

class SuperPrinterApp extends StatefulWidget {
  const SuperPrinterApp({super.key});

  @override
  State<SuperPrinterApp> createState() => _SuperPrinterAppState();
}

class _SuperPrinterAppState extends State<SuperPrinterApp> {
  // Created once per widget instance (not a module-level singleton) so
  // navigation state doesn't leak across separate app runs — see
  // `createAppRouter`.
  late final GoRouter _router = createAppRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FlavorHub Label Print',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: _router,
    );
  }
}
