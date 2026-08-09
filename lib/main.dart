import 'package:flutter/material.dart';
import 'screens/language_screen.dart';
import 'config/app_config.dart';
import 'config/colors.dart';


void main() {
  runApp(const TaxiApp());
}

class TaxiApp extends StatelessWidget {
  const TaxiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
  debugShowCheckedModeBanner: false,
  title: AppConfig.appName,
  theme: ThemeData(
    scaffoldBackgroundColor: AppColors.background,
    primaryColor: AppColors.primary,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    ),
  ),
  home: const LanguageScreen(),
);
  }
}