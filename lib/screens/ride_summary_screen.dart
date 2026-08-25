import 'package:flutter/material.dart';

import '../config/colors.dart';
import '../localization/translations.dart';
import '../models/ride.dart';
import '../models/route_result.dart';
import 'ride_confirmation_screen.dart';

class RideSummaryScreen extends StatelessWidget {
  final String pickup;
  final String destination;
  final int passengers;
  final RidePaymentMethod paymentMethod;
  final RideType rideType;
  final RouteResult? routeResult;
  final double? estimatedPrice;

  const RideSummaryScreen({
    super.key,
    required this.pickup,
    required this.destination,
    required this.passengers,
    required this.paymentMethod,
    required this.rideType,
    this.routeResult,
    this.estimatedPrice,
  });

  String getPaymentText() {
  switch (paymentMethod) {
    case RidePaymentMethod.cash:
      return AppTranslations.cash;

    case RidePaymentMethod.card:
      return AppTranslations.card;

    case RidePaymentMethod.voucher:
      return AppTranslations.voucher;
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GoCity6'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              Text(
                AppTranslations.rideSummary,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 30),

              Text(
                '🚐 ${AppTranslations.vehicleInfo}',
                style: TextStyle(
                  fontSize: 20,
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 25),

              Text(
                '📍 ${AppTranslations.from}: $pickup',
                style: const TextStyle(
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 15),

              Text(
                '📍 ${AppTranslations.to}: $destination',
                style: const TextStyle(
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 15),

              Text(
                '👥 ${AppTranslations.passengersLabel}: $passengers',
                style: const TextStyle(
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 15),

              Text(
                '🚕 ${AppTranslations.rideType}: '
                '${rideType == RideType.city ? AppTranslations.cityRide : AppTranslations.intercityRide}',
                style: const TextStyle(
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 15),

              Text(
                '💳 ${AppTranslations.paymentMethod}: ${getPaymentText()}',
                style: const TextStyle(
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 15),

              Text(
                '🧳 ${AppTranslations.luggage}: '
                '${AppTranslations.luggageInfo}',
                style: const TextStyle(
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 15),
if (routeResult != null) ...[
  Text(
    '🛣️ ${AppTranslations.distance}: '
    '${routeResult!.distanceKm.toStringAsFixed(1)} km',
    style: const TextStyle(
      fontSize: 18,
    ),
  ),

  const SizedBox(height: 15),

  Text(
    '⏱️ ${AppTranslations.estimatedDuration}: '
    '${routeResult!.durationMinutes.toStringAsFixed(0)} '
    '${AppTranslations.minutes}',
    style: const TextStyle(
      fontSize: 18,
    ),
  ),

  const SizedBox(height: 15),
],
              Text(
                '🕒 ${AppTranslations.arrivalTime}: '
                '${AppTranslations.calculating}',
                style: const TextStyle(
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 15),

              Text(
  '💰 ${AppTranslations.priceLabel}: '
  '${estimatedPrice == null ? AppTranslations.calculating : '${estimatedPrice!.toStringAsFixed(2)} лв.'}',
  style: const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
  ),
),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const RideConfirmationScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: AppColors.primary,
                  ),
                  child: Text(
                    AppTranslations.confirmRide,
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