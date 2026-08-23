import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../localization/translations.dart';
import '../models/ride.dart';
import 'ride_summary_screen.dart';

class RideRequestScreen extends StatefulWidget {
  const RideRequestScreen({super.key});

  @override
  State<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends State<RideRequestScreen> {
  int passengers = 1;
  String paymentMethod = 'cash';
  RideType rideType = RideType.city;
  final TextEditingController pickupController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();
  
void submitRide() {
  if (pickupController.text.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
        content: Text(AppTranslations.pickupRequired),
      ),
    );
    return;
  }

  if (destinationController.text.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
        content: Text(AppTranslations.destinationRequired),
      ),
    );
    return;
  }

  Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => RideSummaryScreen(
  pickup: pickupController.text,
  destination: destinationController.text,
  passengers: passengers,
  paymentMethod: paymentMethod,
  rideType: rideType,
),
  ),
);
}

  @override
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
          children: [

            TextField(
              controller: pickupController,
              decoration: InputDecoration(
              labelText: AppTranslations.pickupLocation,
              prefixIcon: const Icon(Icons.location_on),
               border: const OutlineInputBorder(),
),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: destinationController,
              decoration: InputDecoration(
              labelText: AppTranslations.destinationLocation,
                prefixIcon: Icon(Icons.flag),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 30),

            Text(
  AppTranslations.passengers,
  style: const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  ),
),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                IconButton(
                  onPressed: () {
                    if (passengers > 1) {
                      setState(() {
                        passengers--;
                      });
                    }
                  },
                  icon: const Icon(Icons.remove_circle),
                ),

                Text(
                  '$passengers',
                  style: const TextStyle(
                    fontSize: 24,
                  ),
                ),

                IconButton(
                  onPressed: () {
                    if (passengers < 6) {
                      setState(() {
                        passengers++;
                      });
                    }
                  },
                  icon: const Icon(Icons.add_circle),
                ),
              ],
            ),
            Text(
  AppTranslations.rideType,
  style: const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  ),
),

RadioListTile<RideType>(
  title: Text(AppTranslations.cityRide),
  value: RideType.city,
  groupValue: rideType,
  onChanged: (RideType? value) {
    if (value == null) return;

    setState(() {
      rideType = value;
    });
  },
),

RadioListTile<RideType>(
  title: Text(AppTranslations.intercityRide),
  value: RideType.intercity,
  groupValue: rideType,
  onChanged: (RideType? value) {
    if (value == null) return;

    setState(() {
      rideType = value;
    });
  },
),

            const SizedBox(height: 20),

            Text(
  AppTranslations.payment,
  style: const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  ),
),

            RadioListTile<String>(
  title: Text(AppTranslations.cash),
  value: 'cash',
  groupValue: paymentMethod,
  onChanged: (String? value) {
    setState(() {
      paymentMethod = value!;
    });
  },
),

            RadioListTile<String>(
  title: Text(AppTranslations.card),
  value: 'card',
  groupValue: paymentMethod,
  onChanged: (String? value) {
    setState(() {
      paymentMethod = value!;
    });
  },
),
            RadioListTile<String>(
  title: Text(AppTranslations.voucher),
  value: 'voucher',
  groupValue: paymentMethod,
  onChanged: (String? value) {
    setState(() {
      paymentMethod = value!;
    });
  },
),

            const SizedBox(height: 20),

            Text(
  AppTranslations.estimatedPrice,
  style: const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  ),
),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () { submitRide();},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: AppColors.primary,
                ),
                child: Text(
                  AppTranslations.confirmRide,
                  style: TextStyle(
                    fontSize: 18,
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