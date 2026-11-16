import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';

abstract interface class ReverseGeocodeService {
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  });
}

class BackendReverseGeocodeService implements ReverseGeocodeService {
  final String? baseUrl;
  final http.Client? client;
  final Duration timeout;

  const BackendReverseGeocodeService({
    this.baseUrl,
    this.client,
    this.timeout = const Duration(seconds: 10),
  });

  String get _baseUrl => baseUrl ?? BackendConfig.baseUrl;

  @override
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    if (latitude.isNaN ||
        latitude.isInfinite ||
        longitude.isNaN ||
        longitude.isInfinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw ArgumentError('Coordinates must be a valid WGS84 pair.');
    }

    final requestClient = client ?? http.Client();
    final shouldCloseClient = client == null;
    final abortTrigger = Completer<void>();
    final request =
        http.AbortableRequest(
            'POST',
            Uri.parse('$_baseUrl/places/reverse-geocode'),
            abortTrigger: abortTrigger.future,
          )
          ..headers['Content-Type'] = 'application/json; charset=utf-8'
          ..headers['Accept'] = 'application/json'
          ..body = jsonEncode({'latitude': latitude, 'longitude': longitude});
    try {
      final response = await requestClient
          .send(request)
          .then(http.Response.fromStream)
          .timeout(
            timeout,
            onTimeout: () {
              if (!abortTrigger.isCompleted) abortTrigger.complete();
              throw TimeoutException(
                'Reverse geocoding exceeded ${timeout.inSeconds} seconds.',
                timeout,
              );
            },
          );

      if (response.statusCode != 200) {
        throw StateError(
          'Reverse geocoding failed with status ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Reverse-geocode response is invalid.');
      }

      final status = decoded['status'];
      if (status == 'unavailable') return null;
      if (status != 'ok') {
        throw const FormatException('Reverse-geocode status is invalid.');
      }

      final address = decoded['address'];
      if (address is! String || address.trim().isEmpty) return null;
      return address.trim();
    } finally {
      if (shouldCloseClient) requestClient.close();
    }
  }
}
