import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_app/services/mock_route_service.dart';

void main() {
  test('MockRouteService returns route data', () async {
    final routeService = MockRouteService();

    final result = await routeService.calculateRoute(
      pickup: 'Pickup',
      destination: 'Destination',
    );

    expect(result.distanceKm, 10);
    expect(result.durationMinutes, 20);
  });
}