import 'package:flutter/material.dart';

import '../config/colors.dart';
import '../localization/translations.dart';
import '../models/ride_request_data.dart';

class RideConfirmationScreen extends StatelessWidget {
  final RideRequestData request;

  const RideConfirmationScreen({
    super.key,
    required this.request,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GoCity6'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle,
                size: 100,
                color: Colors.green,
              ),

              const SizedBox(height: 30),

              Text(
                AppTranslations.rideRequestSent,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                '💰 ${AppTranslations.priceLabel}: '
                '${request.estimatedPrice == null ? AppTranslations.calculating : '${request.estimatedPrice!.toStringAsFixed(2)} лв.'}',
                style: const TextStyle(
                  fontSize: 20,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                AppTranslations.waitingForDriverConfirmation,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: AppColors.primary,
                  ),
                  child: Text(
                    AppTranslations.backButton,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
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