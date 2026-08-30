import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taxi_app/localization/translations.dart';
import 'package:taxi_app/models/ride.dart';
import 'package:taxi_app/models/ride_request_data.dart';
import 'package:taxi_app/models/ride_request_status.dart';
import 'package:taxi_app/screens/ride_confirmation_screen.dart';
import 'support/mock_ride_request_service.dart';

void main() {
  testWidgets(
    'RideConfirmationScreen shows pending status',
    (WidgetTester tester) async {
      final request = RideRequestData(
        pickup: 'Pickup',
        destination: 'Destination',
        passengers: 1,
        paymentMethod: RidePaymentMethod.cash,
        rideType: RideType.city,
        requestedAt: DateTime(2026, 1, 1, 10, 0),
        status: RideRequestStatus.pending,
        estimatedPrice: 10.50,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RideConfirmationScreen(
            request: request,
          ),
        ),
      );

      expect(
        find.text(AppTranslations.rideRequestSent),
        findsOneWidget,
      );

      expect(
        find.text(AppTranslations.waitingForDriverConfirmation),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'RideConfirmationScreen shows accepted status',
    (WidgetTester tester) async {
      final request = RideRequestData(
        pickup: 'Pickup',
        destination: 'Destination',
        passengers: 1,
        paymentMethod: RidePaymentMethod.cash,
        rideType: RideType.city,
        requestedAt: DateTime(2026, 1, 1, 10, 0),
        status: RideRequestStatus.accepted,
        estimatedPrice: 10.50,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RideConfirmationScreen(
            request: request,
          ),
        ),
      );

      expect(
        find.text(AppTranslations.rideAccepted),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'RideConfirmationScreen updates through stream to completed',
    (WidgetTester tester) async {
      final request = RideRequestData(
        pickup: 'Pickup',
        destination: 'Destination',
        passengers: 1,
        paymentMethod: RidePaymentMethod.cash,
        rideType: RideType.city,
        requestedAt: DateTime(2026, 1, 1, 10, 0),
        status: RideRequestStatus.pending,
        estimatedPrice: 10.50,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RideConfirmationScreen(
            request: request,
            rideRequestService: MockRideRequestService(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text(AppTranslations.rideCompleted),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'RideConfirmationScreen shows driver arriving status',
    (WidgetTester tester) async {
      final request = RideRequestData(
        pickup: 'Pickup',
        destination: 'Destination',
        passengers: 1,
        paymentMethod: RidePaymentMethod.cash,
        rideType: RideType.city,
        requestedAt: DateTime(2026, 1, 1, 10, 0),
        status: RideRequestStatus.driverArriving,
        estimatedPrice: 10.50,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RideConfirmationScreen(
            request: request,
          ),
        ),
      );

      expect(
        find.text(AppTranslations.driverArriving),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'RideConfirmationScreen shows ride in progress status',
    (WidgetTester tester) async {
      final request = RideRequestData(
        pickup: 'Pickup',
        destination: 'Destination',
        passengers: 1,
        paymentMethod: RidePaymentMethod.cash,
        rideType: RideType.city,
        requestedAt: DateTime(2026, 1, 1, 10, 0),
        status: RideRequestStatus.inProgress,
        estimatedPrice: 10.50,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RideConfirmationScreen(
            request: request,
          ),
        ),
      );

      expect(
        find.text(AppTranslations.rideInProgress),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'RideConfirmationScreen shows completed status',
    (WidgetTester tester) async {
      final request = RideRequestData(
        pickup: 'Pickup',
        destination: 'Destination',
        passengers: 1,
        paymentMethod: RidePaymentMethod.cash,
        rideType: RideType.city,
        requestedAt: DateTime(2026, 1, 1, 10, 0),
        status: RideRequestStatus.completed,
        estimatedPrice: 10.50,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RideConfirmationScreen(
            request: request,
          ),
        ),
      );

      expect(
        find.text(AppTranslations.rideCompleted),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'RideConfirmationScreen shows cancelled status',
    (WidgetTester tester) async {
      final request = RideRequestData(
        pickup: 'Pickup',
        destination: 'Destination',
        passengers: 1,
        paymentMethod: RidePaymentMethod.cash,
        rideType: RideType.city,
        requestedAt: DateTime(2026, 1, 1, 10, 0),
        status: RideRequestStatus.cancelled,
        estimatedPrice: 10.50,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RideConfirmationScreen(
            request: request,
          ),
        ),
      );

      expect(
        find.text(AppTranslations.rideCancelled),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'RideConfirmationScreen shows red cancel icon for cancelled ride',
    (WidgetTester tester) async {
      final request = RideRequestData(
        pickup: 'Pickup',
        destination: 'Destination',
        passengers: 1,
        paymentMethod: RidePaymentMethod.cash,
        rideType: RideType.city,
        requestedAt: DateTime(2026, 1, 1, 10, 0),
        status: RideRequestStatus.cancelled,
        estimatedPrice: 10.50,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RideConfirmationScreen(
            request: request,
          ),
        ),
      );

      expect(
        find.byIcon(Icons.cancel),
        findsOneWidget,
      );

      final icon = tester.widget<Icon>(
        find.byIcon(Icons.cancel),
      );

      expect(
        icon.color,
        Colors.red,
      );
    },
  );

  testWidgets(
    'RideConfirmationScreen shows taxi icon for driver arriving',
    (WidgetTester tester) async {
      final request = RideRequestData(
        pickup: 'Pickup',
        destination: 'Destination',
        passengers: 1,
        paymentMethod: RidePaymentMethod.cash,
        rideType: RideType.city,
        requestedAt: DateTime(2026, 1, 1, 10, 0),
        status: RideRequestStatus.driverArriving,
        estimatedPrice: 10.50,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RideConfirmationScreen(
            request: request,
          ),
        ),
      );

      expect(
        find.byIcon(Icons.local_taxi),
        findsOneWidget,
      );

      final icon = tester.widget<Icon>(
        find.byIcon(Icons.local_taxi),
      );

      expect(
        icon.color,
        Colors.blue,
      );
    },
  );
}