import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taxi_app/localization/translations.dart';
import 'package:taxi_app/models/ride.dart';
import 'package:taxi_app/models/ride_request_data.dart';
import 'package:taxi_app/models/ride_request_status.dart';
import 'package:taxi_app/screens/ride_confirmation_screen.dart';
import 'package:taxi_app/screens/ride_summary_screen.dart';
import 'package:taxi_app/services/ride_request_service.dart';

class RecordingRideRequestService implements RideRequestService {
  bool submitCalled = false;
  RideRequestData? submittedRequest;

  @override
  Future<RideRequestData> submitRequest(RideRequestData request) async {
    submitCalled = true;
    submittedRequest = request;

    return request.copyWith(
      requestId: 'recording-request-001',
      status: RideRequestStatus.pending,
    );
  }

  @override
  Future<RideRequestData> getRequestStatus(RideRequestData request) async {
    return request;
  }

  @override
  Stream<RideRequestData> watchRequestStatus(RideRequestData request) async* {
    yield request;
  }
}

void main() {
  testWidgets('RideSummaryScreen submits request before opening confirmation', (
    WidgetTester tester,
  ) async {
    final service = RecordingRideRequestService();

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
        home: RideSummaryScreen.fromRequest(
          request: request,
          rideRequestService: service,
        ),
      ),
    );

    expect(service.submitCalled, isFalse);

    await tester.tap(find.text(AppTranslations.confirmRide));

    await tester.pumpAndSettle();

    expect(service.submitCalled, isTrue);

    expect(service.submittedRequest, same(request));

    expect(find.byType(RideConfirmationScreen), findsOneWidget);
    final confirmationScreen = tester.widget<RideConfirmationScreen>(
      find.byType(RideConfirmationScreen),
    );

    expect(confirmationScreen.request.requestId, 'recording-request-001');
  });
}
