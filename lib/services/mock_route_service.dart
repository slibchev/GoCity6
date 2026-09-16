import '../models/route_result.dart';
import 'route_service.dart';

class MockRouteService implements RouteService {
  @override
  Future<RouteResult> calculateRoute({
    required String pickup,
    required String destination,
    String? pickupPlaceId,
    String? destinationPlaceId,
  }) async {
    return const RouteResult(distanceKm: 10, durationMinutes: 20);
  }
}
