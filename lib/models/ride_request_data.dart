import 'ride.dart';
import 'route_result.dart';
import 'ride_request_status.dart';
import 'driver_info.dart';

class RideRequestData {
  final String? requestId;
  final DriverInfo? driverInfo;
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
    this.requestId,
    this.driverInfo,
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
  RideRequestData copyWith({
    String? requestId,
    DriverInfo? driverInfo,
    String? pickup,
    String? destination,
    int? passengers,
    RidePaymentMethod? paymentMethod,
    RideType? rideType,
    DateTime? requestedAt,
    RideRequestStatus? status,
    RouteResult? routeResult,
    double? estimatedPrice,
  }) {
    return RideRequestData(
      requestId: requestId ?? this.requestId,
      driverInfo: driverInfo ?? this.driverInfo,
      pickup: pickup ?? this.pickup,
      destination: destination ?? this.destination,
      passengers: passengers ?? this.passengers,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      rideType: rideType ?? this.rideType,
      requestedAt: requestedAt ?? this.requestedAt,
      status: status ?? this.status,
      routeResult: routeResult ?? this.routeResult,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
    );
  }
}
