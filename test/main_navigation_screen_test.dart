import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taxi_app/models/ride.dart';
import 'package:taxi_app/models/ride_request_data.dart';
import 'package:taxi_app/models/ride_request_status.dart';
import 'package:taxi_app/screens/main_navigation_screen.dart';
import 'package:taxi_app/screens/ride_confirmation_screen.dart';
import 'package:taxi_app/services/active_ride_store.dart';
import 'package:taxi_app/services/ride_request_service.dart';

class RestoreRideRequestService implements RideRequestService {
  final RideRequestData? refreshedRequest;
  final bool failStatusRequest;

  int getStatusCallCount = 0;

  RestoreRideRequestService({
    this.refreshedRequest,
    this.failStatusRequest = false,
  });

  @override
  Future<RideRequestData> getRequestStatus(RideRequestData request) async {
    getStatusCallCount++;

    if (failStatusRequest) {
      throw StateError('Backend unavailable.');
    }

    return refreshedRequest ?? request;
  }

  @override
  Future<RideRequestData> submitRequest(RideRequestData request) async {
    return request;
  }

  @override
  Future<RideRequestData> cancelRequest(RideRequestData request) async {
    return request;
  }

  @override
  Stream<RideRequestData> watchRequestStatus(RideRequestData request) {
    return const Stream<RideRequestData>.empty();
  }
}

RideRequestData buildRequest({
  required RideRequestStatus status,
  String requestId = 'restore-ride-001',
  String? assignedDriverId,
  String? assignedVehicleId,
}) {
  return RideRequestData(
    requestId: requestId,
    assignedDriverId: assignedDriverId,
    assignedVehicleId: assignedVehicleId,
    pickup: 'Pickup',
    destination: 'Destination',
    passengers: 1,
    paymentMethod: RidePaymentMethod.cash,
    rideType: RideType.city,
    requestedAt: DateTime(2026, 10, 2, 16),
    status: status,
    estimatedPrice: 10.50,
  );
}

void main() {
  testWidgets('restores active ride using refreshed backend status', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final preferences = await SharedPreferences.getInstance();
    final store = ActiveRideStore(preferences);

    final storedRequest = buildRequest(
      status: RideRequestStatus.waitingForVehicle,
    );

    await store.save(storedRequest);

    final refreshedRequest = storedRequest.copyWith(
      status: RideRequestStatus.accepted,
      assignedDriverId: 'driver-001',
      assignedVehicleId: 'vehicle-001',
    );

    final service = RestoreRideRequestService(
      refreshedRequest: refreshedRequest,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MainNavigationScreen(
          activeRideStore: store,
          rideRequestService: service,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(service.getStatusCallCount, 1);
    expect(find.byType(RideConfirmationScreen), findsOneWidget);

    final confirmation = tester.widget<RideConfirmationScreen>(
      find.byType(RideConfirmationScreen),
    );

    expect(confirmation.request.status, RideRequestStatus.accepted);
    expect(confirmation.request.assignedDriverId, 'driver-001');
    expect(confirmation.request.assignedVehicleId, 'vehicle-001');

    final persistedRequest = store.load();

    expect(persistedRequest, isNotNull);
    expect(persistedRequest!.status, RideRequestStatus.accepted);
    expect(persistedRequest.assignedDriverId, 'driver-001');
    expect(persistedRequest.assignedVehicleId, 'vehicle-001');
  });

  testWidgets('clears terminal stored ride without restoring confirmation', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final preferences = await SharedPreferences.getInstance();
    final store = ActiveRideStore(preferences);

    await store.save(buildRequest(status: RideRequestStatus.completed));

    final service = RestoreRideRequestService();

    await tester.pumpWidget(
      MaterialApp(
        home: MainNavigationScreen(
          activeRideStore: store,
          rideRequestService: service,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(service.getStatusCallCount, 0);
    expect(find.byType(RideConfirmationScreen), findsNothing);
    expect(store.load(), isNull);
  });

  testWidgets(
    'keeps and restores stored active ride when backend is unavailable',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      final preferences = await SharedPreferences.getInstance();
      final store = ActiveRideStore(preferences);

      final storedRequest = buildRequest(
        status: RideRequestStatus.waitingForVehicle,
      );

      await store.save(storedRequest);

      final service = RestoreRideRequestService(failStatusRequest: true);

      await tester.pumpWidget(
        MaterialApp(
          home: MainNavigationScreen(
            activeRideStore: store,
            rideRequestService: service,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(service.getStatusCallCount, 1);
      expect(find.byType(RideConfirmationScreen), findsOneWidget);

      final confirmation = tester.widget<RideConfirmationScreen>(
        find.byType(RideConfirmationScreen),
      );

      expect(confirmation.request.status, RideRequestStatus.waitingForVehicle);

      final persistedRequest = store.load();

      expect(persistedRequest, isNotNull);
      expect(persistedRequest!.status, RideRequestStatus.waitingForVehicle);
    },
  );
}
