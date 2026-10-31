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
    String pickup = 'Pickup',
    double? pickupLatitude = 42.6977,
    double? pickupLongitude = 23.3219,
  }) {
    return RideRequestData(
      requestId: requestId,
      clientRequestId: '11111111-2222-4333-8444-555555555555',
      pickup: pickup,
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
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
    Object? meterFareMinor,
    String bonusDecision = 'not_offered',
    Object? driverBonusMinor,
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
      'pickupDistrict': {
        'status': 'matched',
        'objectId': 321,
        'name': 'ЦЕНТЪР 3',
        'resolution': 'interior',
        'candidateObjectIds': [321],
      },
      'bonusDecision': bonusDecision,
      'driverBonusMinor': driverBonusMinor,
      'meterFareMinor': meterFareMinor,
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

        return http.Response.bytes(
          utf8.encode(jsonEncode(backendRide(status: 'pending'))),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = BackendRideRequestService(
        baseUrl: 'http://example.test',
        client: client,
      );

      final local = createRequest(
        pickup: 'Selected Places address',
        pickupLatitude: 42.75,
        pickupLongitude: 23.40,
      );

      final result = await service.submitRequest(local);

      expect(sentBody, {
        'pickup': 'Selected Places address',
        'pickupLatitude': 42.75,
        'pickupLongitude': 23.40,
        'destination': 'Destination',
        'passengers': 2,
        'hasLuggage': true,
        'clientRequestId': '11111111-2222-4333-8444-555555555555',
      });

      expect(result.requestId, 'ride-001');
      expect(result.status, RideRequestStatus.pending);
      expect(result.pickupDistrict?.objectId, 321);
      expect(result.pickupDistrict?.name, 'ЦЕНТЪР 3');
      expect(result.pickupDistrict?.resolution, 'interior');
      expect(result.pickupDistrict?.candidateObjectIds, [321]);

      expect(result.paymentMethod, RidePaymentMethod.card);
      expect(result.rideType, RideType.city);
      expect(result.routeResult, same(local.routeResult));
      expect(result.estimatedPrice, 12.50);
    },
  );

  test(
    'authenticated ride operations attach the Passenger Bearer token',
    () async {
      final observedRequests = <http.Request>[];
      final client = MockClient((request) async {
        observedRequests.add(request);
        if (request.url.path.endsWith('/bonus/accept')) {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode(
                backendRide(bonusDecision: 'accepted', driverBonusMinor: 500),
              ),
            ),
            200,
          );
        }
        if (request.url.path.endsWith('/bonus/decline')) {
          return http.Response.bytes(
            utf8.encode(jsonEncode(backendRide(bonusDecision: 'declined'))),
            200,
          );
        }
        if (request.method == 'GET') {
          return http.Response.bytes(
            utf8.encode(jsonEncode(backendRide())),
            200,
          );
        }
        if (request.url.path.endsWith('/cancel')) {
          return http.Response.bytes(
            utf8.encode(jsonEncode(backendRide(status: 'cancelled'))),
            200,
          );
        }
        return http.Response.bytes(utf8.encode(jsonEncode(backendRide())), 201);
      });
      final service = BackendRideRequestService(
        baseUrl: 'https://unit.test',
        client: client,
        authorizationHeaderProvider: () async => 'Bearer passenger-test-token',
      );

      final ride = createRequest();
      final submitted = await service.submitRequest(ride);
      final identifiedRide = submitted.copyWith(requestId: 'ride-001');
      await service.getRequestStatus(identifiedRide);
      await service.cancelRequest(identifiedRide);
      await service.acceptBonus(identifiedRide);
      await service.declineBonus(identifiedRide);

      expect(observedRequests, hasLength(5));
      for (final request in observedRequests) {
        expect(request.headers['authorization'], 'Bearer passenger-test-token');
      }
      expect(
        observedRequests.map((request) => request.url.path),
        containsAll([
          '/rides',
          '/rides/ride-001',
          '/rides/ride-001/cancel',
          '/rides/ride-001/bonus/accept',
          '/rides/ride-001/bonus/decline',
        ]),
      );
    },
  );

  test(
    'submitRequest sends valid GPS coordinates for current location pickup',
    () async {
      late Map<String, dynamic> sentBody;
      final service = BackendRideRequestService(
        baseUrl: 'http://example.test',
        client: MockClient((request) async {
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode(backendRide()), 201);
        }),
      );

      await service.submitRequest(
        createRequest(
          pickup: 'Моето местоположение',
          pickupLatitude: 42.6977,
          pickupLongitude: 23.3219,
        ),
      );

      expect(sentBody, {
        'pickup': 'Моето местоположение',
        'pickupLatitude': 42.6977,
        'pickupLongitude': 23.3219,
        'destination': 'Destination',
        'passengers': 2,
        'hasLuggage': true,
        'clientRequestId': '11111111-2222-4333-8444-555555555555',
      });
    },
  );

  test(
    'submitRequest sends coordinates for English My location pickup',
    () async {
      late Map<String, dynamic> sentBody;
      final service = BackendRideRequestService(
        baseUrl: 'http://example.test',
        client: MockClient((request) async {
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode(backendRide()), 201);
        }),
      );

      await service.submitRequest(
        createRequest(
          pickup: 'My location',
          pickupLatitude: 42.6977,
          pickupLongitude: 23.3219,
        ),
      );

      expect(sentBody['pickup'], 'My location');
      expect(sentBody['pickupLatitude'], 42.6977);
      expect(sentBody['pickupLongitude'], 23.3219);
    },
  );

  test(
    'submitRequest rejects any pickup without a valid coordinate pair',
    () async {
      var requestCount = 0;
      final service = BackendRideRequestService(
        baseUrl: 'http://example.test',
        client: MockClient((request) async {
          requestCount++;
          return http.Response(jsonEncode(backendRide()), 201);
        }),
      );

      final invalidRequests = [
        createRequest(
          pickup: 'Моето местоположение',
          pickupLatitude: null,
          pickupLongitude: null,
        ),
        createRequest(
          pickup: 'Моето местоположение',
          pickupLatitude: 91,
          pickupLongitude: 23.3219,
        ),
        createRequest(
          pickup: 'Моето местоположение',
          pickupLatitude: 42.6977,
          pickupLongitude: null,
        ),
      ];

      for (final request in invalidRequests) {
        await expectLater(
          service.submitRequest(request),
          throwsA(isA<ArgumentError>()),
        );
      }

      await expectLater(
        service.submitRequest(
          createRequest(
            pickup: 'Selected manual address',
            pickupLatitude: null,
            pickupLongitude: null,
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(requestCount, 0);
    },
  );

  test('retry after timeout preserves client request ID', () async {
    final sentBodies = <Map<String, dynamic>>[];
    var callCount = 0;

    final client = MockClient((request) async {
      callCount++;

      final body = jsonDecode(request.body) as Map<String, dynamic>;
      sentBodies.add(body);

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

    final request = createRequest(
      pickup: 'Моето местоположение',
      pickupLatitude: 42.6977,
      pickupLongitude: 23.3219,
    );

    await expectLater(
      service.submitRequest(request),
      throwsA(isA<TimeoutException>()),
    );

    final recovered = await service.submitRequest(request);

    expect(callCount, 2);
    expect(sentBodies.map((body) => body['clientRequestId']), [
      '11111111-2222-4333-8444-555555555555',
      '11111111-2222-4333-8444-555555555555',
    ]);
    expect(
      sentBodies.map(
        (body) => [body['pickupLatitude'], body['pickupLongitude']],
      ),
      [
        [42.6977, 23.3219],
        [42.6977, 23.3219],
      ],
    );
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

  test(
    'getRequestStatus parses meter fare independently from estimate and bonus',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode(
            backendRide(
              status: 'completed',
              meterFareMinor: 520,
              bonusDecision: 'accepted',
              driverBonusMinor: 500,
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
        createRequest(
          requestId: 'ride-001',
          status: RideRequestStatus.inProgress,
        ),
      );

      expect(result.status, RideRequestStatus.completed);
      expect(result.meterFareMinor, 520);
      expect(result.estimatedPrice, 12.50);
      expect(result.driverBonusMinor, 500);
    },
  );

  test(
    'getRequestStatus accepts zero meter fare as a non-displayable amount',
    () async {
      final service = BackendRideRequestService(
        baseUrl: 'http://example.test',
        client: MockClient(
          (request) async => http.Response(
            jsonEncode(backendRide(status: 'completed', meterFareMinor: 0)),
            200,
          ),
        ),
      );

      final result = await service.getRequestStatus(
        createRequest(requestId: 'ride-001'),
      );

      expect(result.meterFareMinor, 0);
    },
  );

  test('getRequestStatus rejects malformed meter fare values', () async {
    for (final invalidFare in [-1, 520.0, '520']) {
      final service = BackendRideRequestService(
        baseUrl: 'http://example.test',
        client: MockClient(
          (request) async => http.Response(
            jsonEncode(
              backendRide(status: 'completed', meterFareMinor: invalidFare),
            ),
            200,
          ),
        ),
      );

      await expectLater(
        service.getRequestStatus(createRequest(requestId: 'ride-001')),
        throwsA(isA<FormatException>()),
      );
    }
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

  test(
    'watchRequestStatus retries transient failures with bounded backoff and resets after success',
    () async {
      var statusReadCount = 0;
      var activeStatusRequests = 0;
      var maxActiveStatusRequests = 0;
      final pollDelays = <Duration>[];

      final client = MockClient((request) async {
        activeStatusRequests++;
        if (activeStatusRequests > maxActiveStatusRequests) {
          maxActiveStatusRequests = activeStatusRequests;
        }

        try {
          statusReadCount++;
          await Future<void>.delayed(Duration.zero);

          if (statusReadCount <= 6 || statusReadCount == 8) {
            throw http.ClientException(
              'Temporary network failure',
              request.url,
            );
          }

          final status = statusReadCount == 7
              ? 'waitingForVehicle'
              : 'completed';

          return http.Response(jsonEncode(backendRide(status: status)), 200);
        } finally {
          activeStatusRequests--;
        }
      });

      final service = BackendRideRequestService(
        baseUrl: 'http://example.test',
        client: client,
        pollInterval: const Duration(seconds: 3),
        retryBaseInterval: const Duration(seconds: 3),
        maxRetryInterval: const Duration(seconds: 30),
        pollDelay: (duration) async {
          pollDelays.add(duration);
        },
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
      expect(statusReadCount, 9);
      expect(maxActiveStatusRequests, 1);
      expect(pollDelays, [
        const Duration(seconds: 3),
        const Duration(seconds: 3),
        const Duration(seconds: 6),
        const Duration(seconds: 12),
        const Duration(seconds: 24),
        const Duration(seconds: 30),
        const Duration(seconds: 30),
        const Duration(seconds: 3),
        const Duration(seconds: 3),
      ]);
    },
  );

  test('watchRequestStatus aborts a timed out GET before retrying', () async {
    var statusReadCount = 0;
    var activeStatusRequests = 0;
    var maxActiveStatusRequests = 0;
    var firstRequestAborted = false;
    var delayCallCount = 0;
    final firstRequestFinished = Completer<void>();

    final client = MockClient.streaming((request, bodyStream) async {
      statusReadCount++;
      activeStatusRequests++;
      if (activeStatusRequests > maxActiveStatusRequests) {
        maxActiveStatusRequests = activeStatusRequests;
      }

      try {
        if (statusReadCount == 1) {
          final abortTrigger = (request as http.AbortableRequest).abortTrigger!;
          await abortTrigger;
          firstRequestAborted = true;
          throw http.RequestAbortedException(request.url);
        }

        return http.StreamedResponse(
          Stream<List<int>>.value(
            utf8.encode(jsonEncode(backendRide(status: 'completed'))),
          ),
          200,
        );
      } finally {
        activeStatusRequests--;
        if (statusReadCount == 1 && !firstRequestFinished.isCompleted) {
          firstRequestFinished.complete();
        }
      }
    });

    final service = BackendRideRequestService(
      baseUrl: 'http://example.test',
      client: client,
      pollInterval: Duration.zero,
      statusTimeout: const Duration(milliseconds: 10),
      retryBaseInterval: Duration.zero,
      maxRetryInterval: Duration.zero,
      pollDelay: (_) async {
        delayCallCount++;
        if (delayCallCount == 2) {
          await firstRequestFinished.future;
        }
      },
    );

    final statuses = await service
        .watchRequestStatus(createRequest(requestId: 'ride-001'))
        .map((request) => request.status)
        .toList();

    expect(statuses, [RideRequestStatus.pending, RideRequestStatus.completed]);
    expect(statusReadCount, 2);
    expect(firstRequestAborted, isTrue);
    expect(maxActiveStatusRequests, 1);
  });

  test('watchRequestStatus retries transient HTTP status codes', () async {
    for (final statusCode in [408, 429, 503]) {
      var statusReadCount = 0;
      final client = MockClient((request) async {
        statusReadCount++;

        if (statusReadCount == 1) {
          return http.Response('{}', statusCode);
        }

        return http.Response(jsonEncode(backendRide(status: 'completed')), 200);
      });

      final service = BackendRideRequestService(
        baseUrl: 'http://example.test',
        client: client,
        pollInterval: Duration.zero,
        retryBaseInterval: Duration.zero,
        maxRetryInterval: Duration.zero,
        pollDelay: (_) async {},
      );

      final statuses = await service
          .watchRequestStatus(createRequest(requestId: 'ride-001'))
          .map((request) => request.status)
          .toList();

      expect(statusReadCount, 2, reason: 'HTTP $statusCode should be retried');
      expect(statuses.last, RideRequestStatus.completed);
    }
  });

  test(
    'watchRequestStatus surfaces permanent HTTP and malformed JSON errors',
    () async {
      for (final statusCode in [400, 401, 403, 404]) {
        var statusReadCount = 0;
        final service = BackendRideRequestService(
          baseUrl: 'http://example.test',
          client: MockClient((request) async {
            statusReadCount++;
            return http.Response('{}', statusCode);
          }),
          pollInterval: Duration.zero,
          pollDelay: (_) async {},
        );

        await expectLater(
          service
              .watchRequestStatus(createRequest(requestId: 'ride-001'))
              .toList(),
          throwsA(isA<StateError>()),
        );
        expect(statusReadCount, 1, reason: 'HTTP $statusCode must not retry');
      }

      var malformedResponseCount = 0;
      final malformedService = BackendRideRequestService(
        baseUrl: 'http://example.test',
        client: MockClient((request) async {
          malformedResponseCount++;
          return http.Response('{not-json', 200);
        }),
        pollInterval: Duration.zero,
        pollDelay: (_) async {},
      );

      await expectLater(
        malformedService
            .watchRequestStatus(createRequest(requestId: 'ride-001'))
            .toList(),
        throwsA(isA<FormatException>()),
      );
      expect(malformedResponseCount, 1);
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
