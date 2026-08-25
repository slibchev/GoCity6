import 'ride.dart';
import 'route_result.dart';

class RideRequestData {
  final String pickup;
  final String destination;
  final int passengers;

  final RidePaymentMethod paymentMethod;
  final RideType rideType;

  final DateTime requestedAt;

  final RouteResult? routeResult;
  final double? estimatedPrice;

  const RideRequestData({
    required this.pickup,
    required this.destination,
    required this.passengers,
    required this.paymentMethod,
    required this.rideType,
    required this.requestedAt,
    this.routeResult,
    this.estimatedPrice,
  });
}