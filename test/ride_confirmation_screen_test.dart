import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taxi_app/localization/translations.dart';
import 'package:taxi_app/models/ride.dart';
import 'package:taxi_app/models/ride_request_data.dart';
import 'package:taxi_app/models/ride_request_status.dart';
import 'package:taxi_app/screens/ride_confirmation_screen.dart';

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
}