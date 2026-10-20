import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taxi_app/models/ride.dart';
import 'package:taxi_app/models/ride_request_data.dart';
import 'package:taxi_app/models/ride_request_status.dart';
import 'package:taxi_app/screens/main_navigation_screen.dart';
import 'package:taxi_app/screens/ride_request_screen.dart';
import 'package:taxi_app/screens/ride_confirmation_screen.dart';
import 'package:taxi_app/services/active_ride_store.dart';
import 'package:taxi_app/services/backend_ride_request_service.dart';
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
  testWidgets('RideRequestScreen GPS map is active only on the order tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: MainNavigationScreen(restoreActiveRide: false)),
    );
    await tester.pump();

    RideRequestScreen requestScreen = tester.widget<RideRequestScreen>(
      find.byType(RideRequestScreen, skipOffstage: false),
    );
    expect(requestScreen.mapIsActive, isTrue);

    await tester.tap(find.text('Любими'));
    await tester.pump();
    requestScreen = tester.widget<RideRequestScreen>(
      find.byType(RideRequestScreen, skipOffstage: false),
    );
    expect(requestScreen.mapIsActive, isFalse);

    await tester.tap(find.text('Поръчай'));
    await tester.pump();
    requestScreen = tester.widget<RideRequestScreen>(
      find.byType(RideRequestScreen, skipOffstage: false),
    );
    expect(requestScreen.mapIsActive, isTrue);
  });

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

  testWidgets('preserves unresolved submission with client request ID', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final preferences = await SharedPreferences.getInstance();
    final store = ActiveRideStore(preferences);

    final pendingRequest = buildRequest(status: RideRequestStatus.pending)
        .copyWith(
          requestId: null,
          clientRequestId: '11111111-2222-4333-8444-555555555555',
        );

    await store.save(pendingRequest);

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
    expect(store.load()?.requestId, isNull);
    expect(store.load()?.clientRequestId, pendingRequest.clientRequestId);
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

  testWidgets(
    'restores stored ride when the initial Backend status request times out',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      final preferences = await SharedPreferences.getInstance();
      final store = ActiveRideStore(preferences);
      final storedRequest = buildRequest(
        status: RideRequestStatus.waitingForVehicle,
      );
      await store.save(storedRequest);

      var statusRequestCount = 0;
      var requestAborted = false;
      final pollDelayGate = Completer<void>();
      final client = MockClient.streaming((request, bodyStream) async {
        statusRequestCount++;
        final abortTrigger = (request as http.AbortableRequest).abortTrigger!;
        await abortTrigger;
        requestAborted = true;
        throw http.RequestAbortedException(request.url);
      });
      final service = BackendRideRequestService(
        baseUrl: 'http://example.test',
        client: client,
        statusTimeout: const Duration(milliseconds: 10),
        pollInterval: const Duration(days: 1),
        pollDelay: (_) => pollDelayGate.future,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MainNavigationScreen(
            activeRideStore: store,
            rideRequestService: service,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpAndSettle();

      expect(statusRequestCount, 1);
      expect(requestAborted, isTrue);
      expect(find.byType(RideConfirmationScreen), findsOneWidget);

      final confirmation = tester.widget<RideConfirmationScreen>(
        find.byType(RideConfirmationScreen),
      );
      expect(confirmation.request.status, RideRequestStatus.waitingForVehicle);
      expect(store.load()?.status, RideRequestStatus.waitingForVehicle);
    },
  );
}
