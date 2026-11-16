import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_app/services/backend_reverse_geocode_service.dart';

void main() {
  test('posts coordinates and returns the backend address', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.url,
        Uri.parse('https://backend.example/places/reverse-geocode'),
      );
      expect(jsonDecode(request.body), {
        'latitude': 42.6977,
        'longitude': 23.3219,
      });
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'latitude': 42.6977,
            'longitude': 23.3219,
            'address': 'бул. Витоша 1, София',
            'status': 'ok',
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    try {
      final address = await BackendReverseGeocodeService(
        baseUrl: 'https://backend.example',
        client: client,
      ).reverseGeocode(latitude: 42.6977, longitude: 23.3219);
      expect(address, 'бул. Витоша 1, София');
    } finally {
      client.close();
    }
  });

  test('returns null when the backend has no address', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({'address': null, 'status': 'unavailable'}),
        200,
      ),
    );

    try {
      final address = await BackendReverseGeocodeService(
        baseUrl: 'https://backend.example',
        client: client,
      ).reverseGeocode(latitude: 42.6977, longitude: 23.3219);
      expect(address, isNull);
    } finally {
      client.close();
    }
  });

  test('rejects invalid coordinates without making a request', () async {
    var requestCount = 0;
    final client = MockClient((_) async {
      requestCount++;
      return http.Response('{}', 200);
    });

    try {
      await expectLater(
        BackendReverseGeocodeService(
          baseUrl: 'https://backend.example',
          client: client,
        ).reverseGeocode(latitude: 91, longitude: 23),
        throwsArgumentError,
      );
      expect(requestCount, 0);
    } finally {
      client.close();
    }
  });

  test(
    'surfaces HTTP and malformed response errors for caller fallback',
    () async {
      final httpErrorClient = MockClient(
        (_) async => http.Response('unavailable', 503),
      );
      final malformedClient = MockClient(
        (_) async => http.Response('{invalid', 200),
      );

      try {
        await expectLater(
          BackendReverseGeocodeService(
            baseUrl: 'https://backend.example',
            client: httpErrorClient,
          ).reverseGeocode(latitude: 42.7, longitude: 23.3),
          throwsA(isA<StateError>()),
        );
        await expectLater(
          BackendReverseGeocodeService(
            baseUrl: 'https://backend.example',
            client: malformedClient,
          ).reverseGeocode(latitude: 42.7, longitude: 23.3),
          throwsFormatException,
        );
      } finally {
        httpErrorClient.close();
        malformedClient.close();
      }
    },
  );

  test('supports a configurable timeout', () async {
    final client = MockClient((_) => Completer<http.Response>().future);
    try {
      await expectLater(
        BackendReverseGeocodeService(
          baseUrl: 'https://backend.example',
          client: client,
          timeout: const Duration(milliseconds: 10),
        ).reverseGeocode(latitude: 42.7, longitude: 23.3),
        throwsA(isA<TimeoutException>()),
      );
    } finally {
      client.close();
    }
  });
}
