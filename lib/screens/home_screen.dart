import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../config/colors.dart';
import '../localization/translations.dart';
import '../localization/app_language.dart';
import 'ride_request_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, Color(0xFF183A63)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.airport_shuttle,
                    size: 110,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(height: 25),
                  Text(
                    AppConfig.appName,
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    AppTranslations.slogan,
                    style: const TextStyle(
                      fontSize: 22,
                      color: AppColors.secondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppTranslations.comfortText,
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 50),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RideRequestScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 55,
                        vertical: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      AppTranslations.orderButton,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 15,
                right: 15,
                child: ElevatedButton(
                  onPressed: () async {
  final newLanguage =
      AppTranslations.currentLanguage == AppLanguage.bulgarian
          ? AppLanguage.english
          : AppLanguage.bulgarian;

  AppTranslations.currentLanguage = newLanguage;

  final prefs = await SharedPreferences.getInstance();

  await prefs.setString(
    'language',
    newLanguage == AppLanguage.english
        ? 'english'
        : 'bulgarian',
  );

  if (!mounted) return;

  setState(() {});
},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    AppTranslations.currentLanguage == AppLanguage.bulgarian
                        ? 'EN'
                        : 'БГ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
