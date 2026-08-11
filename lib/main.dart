import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/language_screen.dart';
import 'config/app_config.dart';
import 'config/colors.dart';
import 'localization/app_language.dart';
import 'localization/translations.dart';
import 'screens/home_screen.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  final savedLanguage = prefs.getString('language');
  debugPrint('LOADED LANGUAGE: $savedLanguage');
  if (savedLanguage == 'english') {
  AppTranslations.currentLanguage = AppLanguage.english;
} else if (savedLanguage == 'bulgarian') {
  AppTranslations.currentLanguage = AppLanguage.bulgarian;
}

  runApp(TaxiApp(savedLanguage: savedLanguage));
}

class TaxiApp extends StatelessWidget {
  final String? savedLanguage;

  const TaxiApp({
    super.key,
    this.savedLanguage,
  });

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
  home: savedLanguage == null
    ? const LanguageScreen()
    : const HomeScreen(),
);
  }
}