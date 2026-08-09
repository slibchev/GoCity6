import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../config/colors.dart';
import '../localization/app_language.dart';
import '../localization/translations.dart';
import 'home_screen.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              Color(0xFF183A63),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              const Icon(
                Icons.airport_shuttle,
                size: 100,
                color: AppColors.secondary,
              ),

              const SizedBox(height: 25),

              Text(
                AppConfig.appName,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 15),

              Text(
                AppTranslations.slogan,
                style: const TextStyle(
                  fontSize: 20,
                  color: AppColors.secondary,
                  fontStyle: FontStyle.italic,
                ),
              ),

              const SizedBox(height: 50),

              Text(
                AppTranslations.chooseLanguage,
                style: const TextStyle(
                  fontSize: 22,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: () {
                  AppTranslations.currentLanguage =
                      AppLanguage.english;

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HomeScreen(),
                    ),
                  );
                },
                child: Text(
                  AppTranslations.english,
                  style: const TextStyle(
                    fontSize: 20,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () {
                  AppTranslations.currentLanguage =
                      AppLanguage.bulgarian;

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HomeScreen(),
                    ),
                  );
                },
                child: Text(
                  AppTranslations.bulgarian,
                  style: const TextStyle(
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}