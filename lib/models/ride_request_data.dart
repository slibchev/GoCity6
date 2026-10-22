import 'ride.dart';
import 'route_result.dart';
import 'ride_request_status.dart';
import 'driver_info.dart';

const Object _notProvided = Object();

enum RideBonusDecision { notOffered, awaitingCustomer, accepted, declined }

class RideRequestData {
  final String? requestId;
  final String? clientRequestId;
  final RideBonusDecision bonusDecision;
  final int driverBonusMinor;

  // Presentation information shown to the customer.
  final DriverInfo? driverInfo;

  // Authoritative backend relationships.
  final String? assignedDriverId;
  final String? assignedVehicleId;

  final String pickup;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final String destination;
  final int passengers;
  final bool hasLuggage;

  final RidePaymentMethod paymentMethod;
  final RideType rideType;

  final DateTime requestedAt;
  final RideRequestStatus status;

  final RouteResult? routeResult;
  final double? estimatedPrice;
  final int? meterFareMinor;

  // Completion information.
  final String? completedByDriverId;
  final DateTime? completedAt;

  const RideRequestData({
    this.requestId,
    this.clientRequestId,
    this.bonusDecision = RideBonusDecision.notOffered,
    this.driverBonusMinor = 0,
    this.driverInfo,
    this.assignedDriverId,
    this.assignedVehicleId,
    required this.pickup,
    this.pickupLatitude,
    this.pickupLongitude,
    required this.destination,
    required this.passengers,
    this.hasLuggage = false,
    required this.paymentMethod,
    required this.rideType,
    required this.requestedAt,
    this.status = RideRequestStatus.pending,
    this.routeResult,
    this.estimatedPrice,
    this.meterFareMinor,
    this.completedByDriverId,
    this.completedAt,
  });

  static bool isValidPickupCoordinatePair(
    double? latitude,
    double? longitude,
  ) =>
      latitude != null &&
      longitude != null &&
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  bool get hasValidPickupCoordinatePair =>
      isValidPickupCoordinatePair(pickupLatitude, pickupLongitude);

  RideRequestData copyWith({
    Object? requestId = _notProvided,
    Object? clientRequestId = _notProvided,
    RideBonusDecision? bonusDecision,
    int? driverBonusMinor,
    Object? driverInfo = _notProvided,
    Object? assignedDriverId = _notProvided,
    Object? assignedVehicleId = _notProvided,
    String? pickup,
    Object? pickupLatitude = _notProvided,
    Object? pickupLongitude = _notProvided,
    String? destination,
    int? passengers,
    bool? hasLuggage,
    RidePaymentMethod? paymentMethod,
    RideType? rideType,
    DateTime? requestedAt,
    RideRequestStatus? status,
    Object? routeResult = _notProvided,
    Object? estimatedPrice = _notProvided,
    Object? meterFareMinor = _notProvided,
    Object? completedByDriverId = _notProvided,
    Object? completedAt = _notProvided,
  }) {
    return RideRequestData(
      requestId: identical(requestId, _notProvided)
          ? this.requestId
          : requestId as String?,
      clientRequestId: identical(clientRequestId, _notProvided)
          ? this.clientRequestId
          : clientRequestId as String?,
      bonusDecision: bonusDecision ?? this.bonusDecision,
      driverBonusMinor: driverBonusMinor ?? this.driverBonusMinor,
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
      pickupLatitude: identical(pickupLatitude, _notProvided)
          ? this.pickupLatitude
          : pickupLatitude as double?,
      pickupLongitude: identical(pickupLongitude, _notProvided)
          ? this.pickupLongitude
          : pickupLongitude as double?,
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
      meterFareMinor: identical(meterFareMinor, _notProvided)
          ? this.meterFareMinor
          : meterFareMinor as int?,
      completedByDriverId: identical(completedByDriverId, _notProvided)
          ? this.completedByDriverId
          : completedByDriverId as String?,
      completedAt: identical(completedAt, _notProvided)
          ? this.completedAt
          : completedAt as DateTime?,
    );
  }
}
