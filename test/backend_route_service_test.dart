import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_app/services/backend_route_service.dart';

void main() {
  test('uses a 15-second timeout by default', () {
    expect(const BackendRouteService().timeout, const Duration(seconds: 15));
  });

  test('calculates a route from a successful response', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url, Uri.parse('https://backend.example/route'));
      expect(jsonDecode(request.body), {
        'pickup': 'Pickup',
        'destination': 'Destination',
      });

      return http.Response(
        jsonEncode({
          'distanceKm': 4.2,
          'durationMinutes': 8,
          'pickupLatitude': 42.7,
          'pickupLongitude': 23.32,
          'destinationLatitude': 42.71,
          'destinationLongitude': 23.33,
        }),
        200,
      );
    });

    try {
      final result = await BackendRouteService(
        baseUrl: 'https://backend.example',
        client: client,
      ).calculateRoute(pickup: 'Pickup', destination: 'Destination');

      expect(result.distanceKm, 4.2);
      expect(result.durationMinutes, 8);
      expect(result.pickupLatitude, 42.7);
      expect(result.pickupLongitude, 23.32);
      expect(result.destinationLatitude, 42.71);
      expect(result.destinationLongitude, 23.33);
    } finally {
      client.close();
    }
  });

  test('reports an HTTP error response', () async {
    final client = MockClient((_) async => http.Response('Unavailable', 503));

    try {
      await expectLater(
        BackendRouteService(
          baseUrl: 'https://backend.example',
          client: client,
        ).calculateRoute(pickup: 'Pickup', destination: 'Destination'),
        throwsA(isA<Exception>()),
      );
    } finally {
      client.close();
    }
  });

  test('aborts the HTTP request when the configured timeout expires', () async {
    final client = _AbortAwarePendingClient();
    final service = BackendRouteService(
      baseUrl: 'https://backend.example',
      client: client,
      timeout: const Duration(milliseconds: 20),
    );

    await expectLater(
      service.calculateRoute(pickup: 'Pickup', destination: 'Destination'),
      throwsA(isA<TimeoutException>()),
    );
    await client.abortRequested.future;

    expect(client.requestCount, 1);
    expect(client.closed, isFalse);
    client.close();
  });
}

class _AbortAwarePendingClient extends http.BaseClient {
  final Completer<void> abortRequested = Completer<void>();
  int requestCount = 0;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestCount++;
    await request.finalize().drain<void>();

    final abortableRequest = request as http.AbortableRequest;
    await abortableRequest.abortTrigger;
    abortRequested.complete();
    throw http.RequestAbortedException(request.url);
  }

  @override
  void close() {
    closed = true;
  }
}
