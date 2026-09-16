import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/route_result.dart';
import 'route_service.dart';

class BackendRouteService implements RouteService {
  final String baseUrl;

  const BackendRouteService({this.baseUrl = 'http://localhost:8080'});

  @override
  Future<RouteResult> calculateRoute({
    required String pickup,
    required String destination,
    String? pickupPlaceId,
    String? destinationPlaceId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/route'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'pickup': pickup,
        'destination': destination,
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
    );
  }
}
