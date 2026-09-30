import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_app/models/ride.dart';
import 'package:taxi_app/models/ride_request_data.dart';
import 'package:taxi_app/models/ride_request_status.dart';
import 'package:taxi_app/models/route_result.dart';
import 'package:taxi_app/services/backend_ride_request_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RideRequestData createRequest({
    String? requestId,
    RideRequestStatus status = RideRequestStatus.pending,
  }) {
    return RideRequestData(
      requestId: requestId,
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 2,
      hasLuggage: true,
      paymentMethod: RidePaymentMethod.card,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 9, 30, 20, 0),
      status: status,
      routeResult: const RouteResult(
        distanceKm: 4.2,
        durationMinutes: 11,
      ),
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
        expect(
          request.url.toString(),
          'http://example.test/rides',
        );

        sentBody =
            jsonDecode(request.body) as Map<String, dynamic>;

        return http.Response(
          jsonEncode(backendRide(status: 'pending')),
          201,
        );
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
      });

      expect(result.requestId, 'ride-001');
      expect(result.status, RideRequestStatus.pending);

      expect(result.paymentMethod, RidePaymentMethod.card);
      expect(result.rideType, RideType.city);
      expect(result.routeResult, same(local.routeResult));
      expect(result.estimatedPrice, 12.50);
    },
  );

  test(
    'getRequestStatus applies authoritative reservation state',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'http://example.test/rides/ride-001',
        );

        return http.Response(
          jsonEncode(backendRide(status: 'reserved')),
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

      expect(result.status, RideRequestStatus.reserved);
      expect(result.assignedDriverId, isNull);
      expect(result.assignedVehicleId, isNull);
    },
  );

  test(
    'getRequestStatus applies accepted assignment data',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode(
            backendRide(
              status: 'accepted',
              assignedDriverId: 'driver-001',
              assignedVehicleId: 'vehicle-001',
            ),
          ),
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

      expect(result.status, RideRequestStatus.accepted);
      expect(result.assignedDriverId, 'driver-001');
      expect(result.assignedVehicleId, 'vehicle-001');
    },
  );

  test(
    'cancelRequest applies backend cancelled state',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'http://example.test/rides/ride-001/cancel',
        );

        return http.Response(
          jsonEncode(backendRide(status: 'cancelled')),
          200,
        );
      });

      final service = BackendRideRequestService(
        baseUrl: 'http://example.test',
        client: client,
      );

      final result = await service.cancelRequest(
        createRequest(requestId: 'ride-001'),
      );

      expect(result.status, RideRequestStatus.cancelled);
    },
  );

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
          .watchRequestStatus(
            createRequest(requestId: 'ride-001'),
          )
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

  test(
    'status and cancellation require backend request id',
    () async {
      final service = BackendRideRequestService(
        baseUrl: 'http://example.test',
        client: MockClient((request) async {
          throw StateError('HTTP must not be called.');
        }),
      );

      final request = createRequest();

      expect(
        () => service.getRequestStatus(request),
        throwsA(isA<StateError>()),
      );

      expect(
        () => service.cancelRequest(request),
        throwsA(isA<StateError>()),
      );
    },
  );
}
