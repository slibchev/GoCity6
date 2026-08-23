import '../models/route_result.dart';

abstract class RouteService {
  Future<RouteResult> calculateRoute({
    required String pickup,
    required String destination,
  });
}