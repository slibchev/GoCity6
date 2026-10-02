import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/driver_info.dart';
import '../models/ride.dart';
import '../models/ride_request_data.dart';
import '../models/ride_request_status.dart';
import '../models/route_result.dart';

class ActiveRideStore {
  static const String _storageKey = 'activeRide';

  final SharedPreferences preferences;

  const ActiveRideStore(this.preferences);

  Future<void> save(RideRequestData request) async {
    final saved = await preferences.setString(
      _storageKey,
      jsonEncode(_toJson(request)),
    );

    if (!saved) {
      throw StateError('Failed to persist active ride.');
    }
  }

  RideRequestData? load() {
    final raw = preferences.getString(_storageKey);

    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return _fromJson(decoded);
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> clear() async {
    final removed = await preferences.remove(_storageKey);

    if (!removed && preferences.containsKey(_storageKey)) {
      throw StateError('Failed to clear active ride.');
    }
  }

  Map<String, dynamic> _toJson(RideRequestData request) {
    return {
      'requestId': request.requestId,
      'driverInfo': _driverInfoToJson(request.driverInfo),
      'assignedDriverId': request.assignedDriverId,
      'assignedVehicleId': request.assignedVehicleId,
      'pickup': request.pickup,
      'destination': request.destination,
      'passengers': request.passengers,
      'hasLuggage': request.hasLuggage,
      'paymentMethod': request.paymentMethod.name,
      'rideType': request.rideType.name,
      'requestedAt': request.requestedAt.toIso8601String(),
      'status': request.status.name,
      'routeResult': _routeResultToJson(request.routeResult),
      'estimatedPrice': request.estimatedPrice,
      'completedByDriverId': request.completedByDriverId,
      'completedAt': request.completedAt?.toIso8601String(),
    };
  }

  RideRequestData _fromJson(Map<String, dynamic> json) {
    final pickup = json['pickup'];
    final destination = json['destination'];
    final passengers = json['passengers'];
    final hasLuggage = json['hasLuggage'];
    final paymentMethod = json['paymentMethod'];
    final rideType = json['rideType'];
    final requestedAt = json['requestedAt'];
    final status = json['status'];

    if (pickup is! String ||
        destination is! String ||
        passengers is! int ||
        hasLuggage is! bool ||
        paymentMethod is! String ||
        rideType is! String ||
        requestedAt is! String ||
        status is! String) {
      throw const FormatException('Stored active ride is invalid.');
    }

    final parsedRequestedAt = DateTime.tryParse(requestedAt);

    if (parsedRequestedAt == null) {
      throw const FormatException('Stored active ride requestedAt is invalid.');
    }

    final completedAt = json['completedAt'];
    DateTime? parsedCompletedAt;

    if (completedAt != null) {
      if (completedAt is! String) {
        throw const FormatException(
          'Stored active ride completedAt is invalid.',
        );
      }

      parsedCompletedAt = DateTime.tryParse(completedAt);

      if (parsedCompletedAt == null) {
        throw const FormatException(
          'Stored active ride completedAt is invalid.',
        );
      }
    }

    return RideRequestData(
      requestId: _nullableString(json['requestId']),
      driverInfo: _driverInfoFromJson(json['driverInfo']),
      assignedDriverId: _nullableString(json['assignedDriverId']),
      assignedVehicleId: _nullableString(json['assignedVehicleId']),
      pickup: pickup,
      destination: destination,
      passengers: passengers,
      hasLuggage: hasLuggage,
      paymentMethod: RidePaymentMethod.values.byName(paymentMethod),
      rideType: RideType.values.byName(rideType),
      requestedAt: parsedRequestedAt,
      status: RideRequestStatus.values.byName(status),
      routeResult: _routeResultFromJson(json['routeResult']),
      estimatedPrice: _nullableDouble(json['estimatedPrice']),
      completedByDriverId: _nullableString(json['completedByDriverId']),
      completedAt: parsedCompletedAt,
    );
  }

  Map<String, dynamic>? _driverInfoToJson(DriverInfo? driverInfo) {
    if (driverInfo == null) {
      return null;
    }

    return {
      'name': driverInfo.name,
      'vehicle': driverInfo.vehicle,
      'licensePlate': driverInfo.licensePlate,
      'etaMinutes': driverInfo.etaMinutes,
      'phoneNumber': driverInfo.phoneNumber,
    };
  }

  DriverInfo? _driverInfoFromJson(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is! Map<String, dynamic>) {
      throw const FormatException('Stored driver info is invalid.');
    }

    final name = value['name'];
    final vehicle = value['vehicle'];
    final licensePlate = value['licensePlate'];
    final etaMinutes = value['etaMinutes'];

    if (name is! String ||
        (vehicle != null && vehicle is! String) ||
        licensePlate is! String ||
        (etaMinutes != null && etaMinutes is! int)) {
      throw const FormatException('Stored driver info is invalid.');
    }

    return DriverInfo(
      name: name,
      vehicle: vehicle as String?,
      licensePlate: licensePlate,
      etaMinutes: etaMinutes as int?,
      phoneNumber: _nullableString(value['phoneNumber']),
    );
  }

  Map<String, dynamic>? _routeResultToJson(RouteResult? routeResult) {
    if (routeResult == null) {
      return null;
    }

    return {
      'distanceKm': routeResult.distanceKm,
      'durationMinutes': routeResult.durationMinutes,
      'pickupLatitude': routeResult.pickupLatitude,
      'pickupLongitude': routeResult.pickupLongitude,
      'destinationLatitude': routeResult.destinationLatitude,
      'destinationLongitude': routeResult.destinationLongitude,
      'encodedPolyline': routeResult.encodedPolyline,
    };
  }

  RouteResult? _routeResultFromJson(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is! Map<String, dynamic>) {
      throw const FormatException('Stored route result is invalid.');
    }

    final distanceKm = _requiredDouble(value['distanceKm']);
    final durationMinutes = _requiredDouble(value['durationMinutes']);

    return RouteResult(
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
      pickupLatitude: _nullableDouble(value['pickupLatitude']),
      pickupLongitude: _nullableDouble(value['pickupLongitude']),
      destinationLatitude: _nullableDouble(value['destinationLatitude']),
      destinationLongitude: _nullableDouble(value['destinationLongitude']),
      encodedPolyline: _nullableString(value['encodedPolyline']),
    );
  }

  String? _nullableString(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is! String) {
      throw const FormatException('Stored string value is invalid.');
    }

    return value;
  }

  double _requiredDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    throw const FormatException('Stored numeric value is invalid.');
  }

  double? _nullableDouble(Object? value) {
    if (value == null) {
      return null;
    }

    return _requiredDouble(value);
  }
}
