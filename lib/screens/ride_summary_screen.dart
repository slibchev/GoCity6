import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../localization/translations.dart';
import 'ride_confirmation_screen.dart';

class RideSummaryScreen extends StatelessWidget {
  final String pickup;
  final String destination;
  final int passengers;
  final String paymentMethod;
  final double price;

  const RideSummaryScreen({
    super.key,
    required this.pickup,
    required this.destination,
    required this.passengers,
    required this.paymentMethod,
    required this.price,
  });

  @override
  String getPaymentText() {
  switch (paymentMethod) {
    case 'cash':
      return AppTranslations.cash;

    case 'card':
      return AppTranslations.card;

    case 'voucher':
      return AppTranslations.voucher;

    default:
      return paymentMethod;
  }
}
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GoCity6'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),

      body: Padding(
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
  style: const TextStyle(fontSize: 18),
),

            const SizedBox(height: 15),

            Text(
  '📍 ${AppTranslations.to}: $destination',
  style: const TextStyle(fontSize: 18),
),

            const SizedBox(height: 15),

            Text(
  '👥 ${AppTranslations.passengersLabel}: $passengers',
  style: const TextStyle(fontSize: 18),
),

            const SizedBox(height: 15),

            Text(
  '💳 ${AppTranslations.paymentMethod}: ${getPaymentText()}',
  style: const TextStyle(fontSize: 18),
),

            const SizedBox(height: 15),
            Text(
  '🧳 ${AppTranslations.luggage}: ${AppTranslations.luggageInfo}',
  style: const TextStyle(fontSize: 18),
),

const SizedBox(height: 15),

Text(
  '🕒 ${AppTranslations.arrivalTime}: ${AppTranslations.calculating}',
  style: const TextStyle(fontSize: 18),
),

            Text(
  '💰 ${AppTranslations.priceLabel}: ${price.toStringAsFixed(2)}',
  style: const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
  ),
),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () { Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => RideConfirmationScreen(
        price: price,
      ),
    ),
  );},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: AppColors.primary,
                ),
                child: const Text(
                  'Confirm ride',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}