import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/route_result.dart';
import 'route_service.dart';
import '../config/backend_config.dart';

class BackendRouteService implements RouteService {
  final String? baseUrl;

  const BackendRouteService({this.baseUrl});

  String get _baseUrl => baseUrl ?? BackendConfig.baseUrl;

  @override
  Future<RouteResult> calculateRoute({
    required String pickup,
    required String destination,
    String? pickupPlaceId,
    String? destinationPlaceId,
    double? pickupLatitude,
    double? pickupLongitude,
  }) async {
    final response = await http.post(
      Uri.parse('${_baseUrl}/route'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'pickup': pickup,
        'destination': destination,
        if (pickupLatitude != null) 'pickupLatitude': pickupLatitude,
        if (pickupLongitude != null) 'pickupLongitude': pickupLongitude,
        if (pickupPlaceId != null) 'pickupPlaceId': pickupPlaceId,
        if (destinationPlaceId != null)
          'destinationPlaceId': destinationPlaceId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Route calculation failed with status '
        '${response.statusCode}.',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    return RouteResult(
      distanceKm: (data['distanceKm'] as num).toDouble(),
      durationMinutes: (data['durationMinutes'] as num).toDouble(),
      pickupLatitude: (data['pickupLatitude'] as num?)?.toDouble(),
      pickupLongitude: (data['pickupLongitude'] as num?)?.toDouble(),
      destinationLatitude: (data['destinationLatitude'] as num?)?.toDouble(),
      destinationLongitude: (data['destinationLongitude'] as num?)?.toDouble(),
      encodedPolyline: data['encodedPolyline'] as String?,
    );
  }
}
