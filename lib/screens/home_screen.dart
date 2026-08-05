import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../config/colors.dart';
import '../localization/translations.dart';
import 'ride_request_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
                AppConfig.slogan,
                style: const TextStyle(
                  fontSize: 22,
                  color: AppColors.secondary,
                  fontStyle: FontStyle.italic,
                ),
              ),

              const SizedBox(height: 20),

              Text(
  AppTranslations.comfortText,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),

              const SizedBox(height: 50),

              ElevatedButton(
                onPressed: () { Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const RideRequestScreen(),
    ),
  );},
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
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
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