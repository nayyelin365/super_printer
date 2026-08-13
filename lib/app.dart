import 'package:flutter/material.dart';

import 'features/home/presentation/home_screen.dart';
import 'shared/theme/app_theme.dart';

class SuperPrinterApp extends StatelessWidget {
  const SuperPrinterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlavorHub Label Print',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const HomeScreen(),
    );
  }
}
