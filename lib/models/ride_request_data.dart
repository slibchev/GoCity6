import 'ride.dart';
import 'route_result.dart';
import 'ride_request_status.dart';
import 'driver_info.dart';

const Object _notProvided = Object();

class RideRequestData {
  final String? requestId;

  // Presentation information shown to the customer.
  final DriverInfo? driverInfo;

  // Authoritative backend relationships.
  final String? assignedDriverId;
  final String? assignedVehicleId;

  final String pickup;
  final String destination;
  final int passengers;
  final bool hasLuggage;

  final RidePaymentMethod paymentMethod;
  final RideType rideType;

  final DateTime requestedAt;
  final RideRequestStatus status;

  final RouteResult? routeResult;
  final double? estimatedPrice;

  // Completion information.
  final String? completedByDriverId;
  final DateTime? completedAt;

  const RideRequestData({
    this.requestId,
    this.driverInfo,
    this.assignedDriverId,
    this.assignedVehicleId,
    required this.pickup,
    required this.destination,
    required this.passengers,
    this.hasLuggage = false,
    required this.paymentMethod,
    required this.rideType,
    required this.requestedAt,
    this.status = RideRequestStatus.pending,
    this.routeResult,
    this.estimatedPrice,
    this.completedByDriverId,
    this.completedAt,
  });

  RideRequestData copyWith({
    Object? requestId = _notProvided,
    Object? driverInfo = _notProvided,
    Object? assignedDriverId = _notProvided,
    Object? assignedVehicleId = _notProvided,
    String? pickup,
    String? destination,
    int? passengers,
    bool? hasLuggage,
    RidePaymentMethod? paymentMethod,
    RideType? rideType,
    DateTime? requestedAt,
    RideRequestStatus? status,
    Object? routeResult = _notProvided,
    Object? estimatedPrice = _notProvided,
    Object? completedByDriverId = _notProvided,
    Object? completedAt = _notProvided,
  }) {
    return RideRequestData(
      requestId: identical(requestId, _notProvided)
          ? this.requestId
          : requestId as String?,
      driverInfo: identical(driverInfo, _notProvided)
          ? this.driverInfo
          : driverInfo as DriverInfo?,
      assignedDriverId: identical(assignedDriverId, _notProvided)
          ? this.assignedDriverId
          : assignedDriverId as String?,
      assignedVehicleId: identical(assignedVehicleId, _notProvided)
          ? this.assignedVehicleId
          : assignedVehicleId as String?,
      pickup: pickup ?? this.pickup,
      destination: destination ?? this.destination,
      passengers: passengers ?? this.passengers,
      hasLuggage: hasLuggage ?? this.hasLuggage,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      rideType: rideType ?? this.rideType,
      requestedAt: requestedAt ?? this.requestedAt,
      status: status ?? this.status,
      routeResult: identical(routeResult, _notProvided)
          ? this.routeResult
          : routeResult as RouteResult?,
      estimatedPrice: identical(estimatedPrice, _notProvided)
          ? this.estimatedPrice
          : estimatedPrice as double?,
      completedByDriverId:
          identical(completedByDriverId, _notProvided)
              ? this.completedByDriverId
              : completedByDriverId as String?,
      completedAt: identical(completedAt, _notProvided)
          ? this.completedAt
          : completedAt as DateTime?,
    );
  }
}