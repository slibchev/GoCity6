import 'dart:async';
import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../localization/translations.dart';
import '../models/ride_request_data.dart';
import '../models/ride_request_status.dart';
import '../services/ride_request_service.dart';
import 'package:url_launcher/url_launcher.dart';

typedef PhoneLauncher = Future<bool> Function(Uri uri);

class RideConfirmationScreen extends StatefulWidget {
  final RideRequestData request;
  final RideRequestService? rideRequestService;
  final PhoneLauncher? phoneLauncher;

  const RideConfirmationScreen({
    super.key,
    required this.request,
    this.rideRequestService,
    this.phoneLauncher,
  });

  @override
  State<RideConfirmationScreen> createState() => _RideConfirmationScreenState();
}

class _RideConfirmationScreenState extends State<RideConfirmationScreen> {
  late RideRequestData currentRequest;

  StreamSubscription<RideRequestData>? _statusSubscription;

  @override
  void initState() {
    super.initState();

    currentRequest = widget.request;
    _watchStatus();
  }

  void _watchStatus() {
    final service = widget.rideRequestService;

    if (service == null) {
      return;
    }

    _statusSubscription = service
        .watchRequestStatus(currentRequest)
        .listen(
          (updatedRequest) {
            if (!mounted) {
              return;
            }

            setState(() {
              currentRequest = updatedRequest;
            });
          },
          onError: (error) {
            // Засега запазваме последния известен статус.
            // По-късно ще покажем проблем с връзката в UI.
          },
        );
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  IconData getStatusIcon() {
    switch (currentRequest.status) {
      case RideRequestStatus.pending:
        return Icons.hourglass_top;

      case RideRequestStatus.accepted:
        return Icons.check_circle;

      case RideRequestStatus.driverArriving:
        return Icons.local_taxi;

      case RideRequestStatus.inProgress:
        return Icons.route;

      case RideRequestStatus.completed:
        return Icons.check_circle;

      case RideRequestStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color getStatusColor() {
    switch (currentRequest.status) {
      case RideRequestStatus.pending:
        return Colors.orange;

      case RideRequestStatus.accepted:
        return Colors.green;

      case RideRequestStatus.driverArriving:
        return Colors.blue;

      case RideRequestStatus.inProgress:
        return Colors.blue;

      case RideRequestStatus.completed:
        return Colors.green;

      case RideRequestStatus.cancelled:
        return Colors.red;
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

  Future<void> _callDriver(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);

    try {
      final launcher = widget.phoneLauncher ?? launchUrl;

      final launched = await launcher(uri);

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppTranslations.callDriverFailed)),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppTranslations.callDriverFailed)));
    }
  }

  Widget buildDriverInfo() {
    final driverInfo = currentRequest.driverInfo;

    if (currentRequest.status != RideRequestStatus.driverArriving ||
        driverInfo == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const SizedBox(height: 25),

        const Divider(),

        const SizedBox(height: 15),

        Text(
          '👤 ${driverInfo.name}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 10),

        Text('🚐 ${driverInfo.vehicle}', style: const TextStyle(fontSize: 18)),

        const SizedBox(height: 10),

        Text(
          '🔢 ${driverInfo.licensePlate}',
          style: const TextStyle(fontSize: 18),
        ),

        if (driverInfo.etaMinutes != null) ...[
          const SizedBox(height: 10),

          Text(
            '⏱️ ${AppTranslations.arrivalTime}: '
            '${driverInfo.etaMinutes} ${AppTranslations.minutes}',
            style: const TextStyle(fontSize: 18),
          ),
        ],

        if (driverInfo.phoneNumber != null) ...[
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () {
                _callDriver(driverInfo.phoneNumber!);
              },
              icon: const Icon(Icons.phone),
              label: Text(AppTranslations.callDriver),
            ),
          ),
        ],
      ],
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(getStatusIcon(), size: 100, color: getStatusColor()),

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
                style: const TextStyle(fontSize: 20),
              ),

              const SizedBox(height: 20),

              Text(
                getStatusMessage(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              buildDriverInfo(),
              if (currentRequest.status.canBeCancelled) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      // Реалното отказване ще добавим в следваща стъпка.
                    },
                    child: Text(AppTranslations.cancelRide),
                  ),
                ),

                const SizedBox(height: 15),
              ],

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
