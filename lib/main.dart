import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/app_config.dart';
import 'config/colors.dart';
import 'localization/app_language.dart';
import 'localization/translations.dart';
import 'screens/registration_screen.dart';
import 'screens/city6_intro_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  final savedLanguage = prefs.getString('language');

  if (savedLanguage == 'english') {
    AppTranslations.currentLanguage = AppLanguage.english;
  } else if (savedLanguage == 'bulgarian') {
    AppTranslations.currentLanguage = AppLanguage.bulgarian;
  }

  final isRegistered = prefs.getBool('isRegistered') ?? false;

  runApp(TaxiApp(savedLanguage: savedLanguage, isRegistered: isRegistered));
}

class TaxiApp extends StatelessWidget {
  final String? savedLanguage;
  final bool isRegistered;

  const TaxiApp({super.key, this.savedLanguage, required this.isRegistered});

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
      home: isRegistered
          ? const City6IntroScreen(
              backgroundAsset: 'assets/images/city6_intro_background.png',
              logoAsset: 'assets/images/city6_intro_logo.png',
            )
          : const RegistrationScreen(),
    );
  }
}
