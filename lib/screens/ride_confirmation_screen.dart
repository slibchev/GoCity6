import 'package:flutter/material.dart';

import '../config/colors.dart';
import '../localization/translations.dart';
import '../models/ride_request_data.dart';
import '../models/ride_request_status.dart';
import '../services/ride_request_service.dart';

class RideConfirmationScreen extends StatefulWidget {
  final RideRequestData request;
  final RideRequestService? rideRequestService;

  const RideConfirmationScreen({
    super.key,
    required this.request,
    this.rideRequestService,
  });

  @override
  State<RideConfirmationScreen> createState() =>
      _RideConfirmationScreenState();
}

class _RideConfirmationScreenState
    extends State<RideConfirmationScreen> {
  late RideRequestData currentRequest;

  @override
void initState() {
  super.initState();

  currentRequest = widget.request;
  _refreshStatus();
}

Future<void> _refreshStatus() async {
  final service = widget.rideRequestService;

  if (service == null) {
    return;
  }

  try {
    final updatedRequest = await service.getRequestStatus(
      currentRequest,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      currentRequest = updatedRequest;
    });
  } catch (error) {
    // Засега запазваме текущия статус при грешка.
    // По-късно ще добавим отделно UI съобщение за проблем с връзката.
  }
}

  String getStatusTitle() {
    switch (currentRequest.status) {
      case RideRequestStatus.pending:
        return AppTranslations.rideRequestSent;

      case RideRequestStatus.accepted:
        return AppTranslations.rideAccepted;

      case RideRequestStatus.driverArriving:
        return AppTranslations.driverArriving;

      case RideRequestStatus.inProgress:
        return AppTranslations.rideInProgress;

      case RideRequestStatus.completed:
        return AppTranslations.rideCompleted;

      case RideRequestStatus.cancelled:
        return AppTranslations.rideCancelled;
    }
  }

  String getStatusMessage() {
    switch (currentRequest.status) {
      case RideRequestStatus.pending:
        return AppTranslations.waitingForDriverConfirmation;

      case RideRequestStatus.accepted:
        return AppTranslations.rideAccepted;

      case RideRequestStatus.driverArriving:
        return AppTranslations.driverArriving;

      case RideRequestStatus.inProgress:
        return AppTranslations.rideInProgress;

      case RideRequestStatus.completed:
        return AppTranslations.rideCompleted;

      case RideRequestStatus.cancelled:
        return AppTranslations.rideCancelled;
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
                getStatusTitle(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                '💰 ${AppTranslations.priceLabel}: '
                '${currentRequest.estimatedPrice == null ? AppTranslations.calculating : '${currentRequest.estimatedPrice!.toStringAsFixed(2)} лв.'}',
                style: const TextStyle(
                  fontSize: 20,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                getStatusMessage(),
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