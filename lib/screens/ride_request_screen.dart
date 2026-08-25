import 'package:flutter/material.dart';

import '../config/colors.dart';
import '../localization/translations.dart';
import '../models/ride.dart';
import '../services/route_service.dart';
import 'ride_summary_screen.dart';
import '../services/pricing_calculator.dart';

class RideRequestScreen extends StatefulWidget {
  final RouteService? routeService;
  final DateTime Function() now;

  RideRequestScreen({
  super.key,
  this.routeService,
  DateTime Function()? now,
}) : now = now ?? DateTime.now;

  @override
  State<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends State<RideRequestScreen> {
  int passengers = 1;
  RidePaymentMethod paymentMethod = RidePaymentMethod.cash;
  RideType rideType = RideType.city;
  bool isCalculatingRoute = false;

  final TextEditingController pickupController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();

  Future<void> submitRide() async {
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

    if (widget.routeService == null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RideSummaryScreen(
            pickup: pickupController.text.trim(),
            destination: destinationController.text.trim(),
            passengers: passengers,
           paymentMethod: paymentMethod,
            rideType: rideType,
          ),
        ),
      );

      return;
    }

    setState(() {
      isCalculatingRoute = true;
    });

    try {
      final routeResult = await widget.routeService!.calculateRoute(
        pickup: pickupController.text.trim(),
        destination: destinationController.text.trim(),
      );

      if (!mounted) {
        return;
      }
      final estimatedPrice = PricingCalculator.calculateEstimatedPrice(
  startTime: widget.now(),
  kilometers: routeResult.distanceKm,
  intercity: rideType == RideType.intercity,
);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RideSummaryScreen(
            pickup: pickupController.text.trim(),
            destination: destinationController.text.trim(),
            passengers: passengers,
           paymentMethod: paymentMethod,
            rideType: rideType,
            routeResult: routeResult,
            estimatedPrice: estimatedPrice,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppTranslations.routeCalculationFailed),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isCalculatingRoute = false;
        });
      }
    }
  }

  @override
  void dispose() {
    pickupController.dispose();
    destinationController.dispose();
    super.dispose();
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
                  prefixIcon: const Icon(Icons.flag),
                  border: const OutlineInputBorder(),
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
                  if (value == null) {
                    return;
                  }

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
                  if (value == null) {
                    return;
                  }

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

              RadioListTile<RidePaymentMethod>(
  title: Text(AppTranslations.cash),
  value: RidePaymentMethod.cash,
  groupValue: paymentMethod,
  onChanged: (RidePaymentMethod? value) {
    if (value == null) {
      return;
    }

    setState(() {
      paymentMethod = value;
    });
  },
),

              RadioListTile<RidePaymentMethod>(
  title: Text(AppTranslations.card),
  value: RidePaymentMethod.card,
  groupValue: paymentMethod,
  onChanged: (RidePaymentMethod? value) {
    if (value == null) {
      return;
    }

    setState(() {
      paymentMethod = value;
    });
  },
),

              RadioListTile<RidePaymentMethod>(
  title: Text(AppTranslations.voucher),
  value: RidePaymentMethod.voucher,
  groupValue: paymentMethod,
  onChanged: (RidePaymentMethod? value) {
    if (value == null) {
      return;
    }

    setState(() {
      paymentMethod = value;
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

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed:
                      isCalculatingRoute ? null : submitRide,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: AppColors.primary,
                  ),
                  child: Text(
                    AppTranslations.confirmRide,
                    style: const TextStyle(
                      fontSize: 18,
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