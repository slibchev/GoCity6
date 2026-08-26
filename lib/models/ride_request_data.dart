import 'ride.dart';
import 'route_result.dart';
import 'ride_request_status.dart';

class RideRequestData {
  final String pickup;
  final String destination;
  final int passengers;

  final RidePaymentMethod paymentMethod;
  final RideType rideType;

  final DateTime requestedAt;
  final RideRequestStatus status;

  final RouteResult? routeResult;
  final double? estimatedPrice;

  const RideRequestData({
    required this.pickup,
    required this.destination,
    required this.passengers,
    required this.paymentMethod,
    required this.rideType,
    required this.requestedAt,
    this.status = RideRequestStatus.pending,
    this.routeResult,
    this.estimatedPrice,
  });
}