import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_app/models/ride.dart';
import 'package:taxi_app/models/ride_request_data.dart';
import 'package:taxi_app/models/ride_request_status.dart';
import 'package:taxi_app/models/route_result.dart';
import 'package:taxi_app/services/backend_ride_request_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_app/models/driver_info.dart';

void main() {
  RideRequestData createRequest({
    String? requestId,
    RideRequestStatus status = RideRequestStatus.pending,
  }) {
    return RideRequestData(
      requestId: requestId,
      clientRequestId: '11111111-2222-4333-8444-555555555555',
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 2,
      hasLuggage: true,
      paymentMethod: RidePaymentMethod.card,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 9, 30, 20, 0),
      status: status,
      routeResult: const RouteResult(distanceKm: 4.2, durationMinutes: 11),
      estimatedPrice: 12.50,
    );
  }

  Map<String, dynamic> backendRide({
    String status = 'pending',
    String? assignedDriverId,
    String? assignedVehicleId,
    String? completedByDriverId,
    String? completedAt,
  }) {
    return {
      'id': 'ride-001',
      'pickup': 'Pickup',
      'destination': 'Destination',
      'passengers': 2,
      'hasLuggage': true,
      'requestedAt': '2026-09-30T17:00:00.000Z',
      'status': status,
      'assignedDriverId': assignedDriverId,
      'assignedVehicleId': assignedVehicleId,
      'currency': 'EUR',
      'meterFareMinor': null,
      'commissionRateBps': null,
      'commissionAmountMinor': null,
      'completedByDriverId': completedByDriverId,
      'completedAt': completedAt,
    };
  }

  test(
    'submitRequest creates backend ride and preserves local presentation data',
    () async {
      late Map<String, dynamic> sentBody;

      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'http://example.test/rides');

        sentBody = jsonDecode(request.body) as Map<String, dynamic>;

        return http.Response(jsonEncode(backendRide(status: 'pending')), 201);
      });

      final service = BackendRideRequestService(
        baseUrl: 'http://example.test',
        client: client,
      );

      final local = createRequest();

      final result = await service.submitRequest(local);

      expect(sentBody, {
        'pickup': 'Pickup',
        'destination': 'Destination',
        'passengers': 2,
        'hasLuggage': true,
        'clientRequestId': '11111111-2222-4333-8444-555555555555',
      });

      expect(result.requestId, 'ride-001');
      expect(result.status, RideRequestStatus.pending);

      expect(result.paymentMethod, RidePaymentMethod.card);
      expect(result.rideType, RideType.city);
      expect(result.routeResult, same(local.routeResult));
      expect(result.estimatedPrice, 12.50);
    },
  );

  test('retry after timeout preserves client request ID', () async {
    final sentIds = <String?>[];
    var callCount = 0;

    final client = MockClient((request) async {
      callCount++;

      final body = jsonDecode(request.body) as Map<String, dynamic>;
      sentIds.add(body['clientRequestId'] as String?);

      if (callCount == 1) {
        // Simulate a request whose response never reaches the client.
        return Completer<http.Response>().future;
      }

      return http.Response(jsonEncode(backendRide()), 201);
    });

    final service = BackendRideRequestService(
      baseUrl: 'http://example.test',
      client: client,
      submitTimeout: const Duration(milliseconds: 30),
    );

    final request = createRequest();

    await expectLater(
      service.submitRequest(request),
      throwsA(isA<TimeoutException>()),
    );

    final recovered = await service.submitRequest(request);

    expect(callCount, 2);
    expect(sentIds, [
      '11111111-2222-4333-8444-555555555555',
      '11111111-2222-4333-8444-555555555555',
    ]);
    expect(recovered.requestId, 'ride-001');
    expect(recovered.status, RideRequestStatus.pending);
  });
  test('reads awaiting customer bonus decision from backend', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          ...backendRide(),
          'bonusDecision': 'awaiting_customer',
          'driverBonusMinor': 0,
        }),
        200,
      );
    });

    final service = BackendRideRequestService(
      baseUrl: 'http://example.test',
      client: client,
    );

    final result = await service.getRequestStatus(
      createRequest(requestId: 'ride-001'),
    );

    expect(result.bonusDecision, RideBonusDecision.awaitingCustomer);
    expect(result.driverBonusMinor, 0);
  });
  test('acceptBonus starts the bonus dispatch round', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'http://example.test/rides/ride-001/bonus/accept',
      );

      return http.Response(
        jsonEncode({
          ...backendRide(),
          'bonusDecision': 'accepted',
          'driverBonusMinor': 500,
        }),
        200,
      );
    });

    final service = BackendRideRequestService(
      baseUrl: 'http://example.test',
      client: client,
    );

    final result = await service.acceptBonus(
      createRequest(requestId: 'ride-001'),
    );

    expect(result.bonusDecision, RideBonusDecision.accepted);
    expect(result.driverBonusMinor, 500);
  });

  test('declineBonus continues without a bonus', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'http://example.test/rides/ride-001/bonus/decline',
      );

      return http.Response(
        jsonEncode({
          ...backendRide(status: 'waitingForVehicle'),
          'bonusDecision': 'declined',
          'driverBonusMinor': 0,
        }),
        200,
      );
    });

    final service = BackendRideRequestService(
      baseUrl: 'http://example.test',
      client: client,
    );

    final result = await service.declineBonus(
      createRequest(requestId: 'ride-001'),
    );

    expect(result.bonusDecision, RideBonusDecision.declined);
    expect(result.status, RideRequestStatus.waitingForVehicle);
    expect(result.driverBonusMinor, 0);
  });

  test('recovers an already accepted bonus after HTTP 409', () async {
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        return http.Response('{"error":"Conflict"}', 409);
      }

      expect(request.method, 'GET');

      return http.Response(
        jsonEncode({
          ...backendRide(),
          'bonusDecision': 'accepted',
          'driverBonusMinor': 500,
        }),
        200,
      );
    });

    final service = BackendRideRequestService(
      baseUrl: 'http://example.test',
      client: client,
    );

    final result = await service.acceptBonus(
      createRequest(requestId: 'ride-001'),
    );

    expect(result.bonusDecision, RideBonusDecision.accepted);
    expect(result.driverBonusMinor, 500);
  });
  test('getRequestStatus applies authoritative reservation state', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.toString(), 'http://example.test/rides/ride-001');

      return http.Response(jsonEncode(backendRide(status: 'reserved')), 200);
    });

    final service = BackendRideRequestService(
      baseUrl: 'http://example.test',
      client: client,
    );

    final result = await service.getRequestStatus(
      createRequest(requestId: 'ride-001'),
    );

    expect(result.status, RideRequestStatus.reserved);
    expect(result.assignedDriverId, isNull);
    expect(result.assignedVehicleId, isNull);
  });

  test('getRequestStatus applies accepted assignment data', () async {
    final client = MockClient((request) async {
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            ...backendRide(
              status: 'accepted',
              assignedDriverId: 'driver-001',
              assignedVehicleId: 'vehicle-001',
            ),
            'driverInfo': {
              'driverId': 'driver-001',
              'vehicleId': 'vehicle-001',
              'name': 'Иван Иванов',
              'phoneNumber': '+359888123456',
              'licensePlate': 'CA1234AB',
            },
          }),
        ),
        200,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    });

    final service = BackendRideRequestService(
      baseUrl: 'http://example.test',
      client: client,
    );

    final result = await service.getRequestStatus(
      createRequest(requestId: 'ride-001'),
    );

    expect(result.status, RideRequestStatus.accepted);
    expect(result.assignedDriverId, 'driver-001');
    expect(result.assignedVehicleId, 'vehicle-001');
    expect(result.driverInfo, isA<DriverInfo>());
    expect(result.driverInfo!.name, 'Иван Иванов');
    expect(result.driverInfo!.vehicle, isNull);
    expect(result.driverInfo!.licensePlate, 'CA1234AB');
    expect(result.driverInfo!.phoneNumber, '+359888123456');
    expect(result.driverInfo!.etaMinutes, isNull);
  });

  test('cancelRequest applies backend cancelled state', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'http://example.test/rides/ride-001/cancel',
      );

      return http.Response(jsonEncode(backendRide(status: 'cancelled')), 200);
    });

    final service = BackendRideRequestService(
      baseUrl: 'http://example.test',
      client: client,
    );

    final result = await service.cancelRequest(
      createRequest(requestId: 'ride-001'),
    );

    expect(result.status, RideRequestStatus.cancelled);
  });

  test(
    'watchRequestStatus polls until backend returns terminal state',
    () async {
      var statusReadCount = 0;

      final client = MockClient((request) async {
        statusReadCount += 1;

        if (statusReadCount == 1) {
          return http.Response(
            jsonEncode(backendRide(status: 'waitingForVehicle')),
            200,
          );
        }

        return http.Response(
          jsonEncode(
            backendRide(
              status: 'completed',
              assignedDriverId: 'driver-001',
              assignedVehicleId: 'vehicle-001',
              completedByDriverId: 'driver-001',
              completedAt: '2026-09-30T17:30:00.000Z',
            ),
          ),
          200,
        );
      });

      final service = BackendRideRequestService(
        baseUrl: 'http://example.test',
        client: client,
        pollInterval: Duration.zero,
      );

      final statuses = await service
          .watchRequestStatus(createRequest(requestId: 'ride-001'))
          .map((request) => request.status)
          .toList();

      expect(statuses, [
        RideRequestStatus.pending,
        RideRequestStatus.waitingForVehicle,
        RideRequestStatus.completed,
      ]);

      expect(statusReadCount, 2);
    },
  );

  test('status and cancellation require backend request id', () async {
    final service = BackendRideRequestService(
      baseUrl: 'http://example.test',
      client: MockClient((request) async {
        throw StateError('HTTP must not be called.');
      }),
    );

    final request = createRequest();

    expect(() => service.getRequestStatus(request), throwsA(isA<StateError>()));

    expect(() => service.cancelRequest(request), throwsA(isA<StateError>()));
  });
}
