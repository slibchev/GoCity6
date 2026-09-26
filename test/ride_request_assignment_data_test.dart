import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_app/models/driver_info.dart';
import 'package:taxi_app/models/ride.dart';
import 'package:taxi_app/models/ride_request_data.dart';
import 'package:taxi_app/models/ride_request_status.dart';

void main() {
  RideRequestData createRequest({
    String? assignedDriverId,
    String? assignedVehicleId,
    String? completedByDriverId,
    DateTime? completedAt,
    DriverInfo? driverInfo,
  }) {
    return RideRequestData(
      requestId: 'ride-001',
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 1,
      paymentMethod: RidePaymentMethod.cash,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 9, 26, 10, 0),
      status: RideRequestStatus.reserved,
      estimatedPrice: 20.00,
      assignedDriverId: assignedDriverId,
      assignedVehicleId: assignedVehicleId,
      completedByDriverId: completedByDriverId,
      completedAt: completedAt,
      driverInfo: driverInfo,
    );
  }

  test('RideRequestData stores driver vehicle and completion data', () {
    final completedAt = DateTime(2026, 9, 26, 10, 45);

    final request = createRequest(
      assignedDriverId: 'driver-001',
      assignedVehicleId: 'vehicle-001',
      completedByDriverId: 'driver-001',
      completedAt: completedAt,
    );

    expect(request.assignedDriverId, 'driver-001');
    expect(request.assignedVehicleId, 'vehicle-001');
    expect(request.completedByDriverId, 'driver-001');
    expect(request.completedAt, completedAt);
  });

  test('copyWith keeps assignment data when values are not provided', () {
    final completedAt = DateTime(2026, 9, 26, 10, 45);

    final request = createRequest(
      assignedDriverId: 'driver-001',
      assignedVehicleId: 'vehicle-001',
      completedByDriverId: 'driver-001',
      completedAt: completedAt,
    );

    final updatedRequest = request.copyWith(
      status: RideRequestStatus.completed,
    );

    expect(updatedRequest.status, RideRequestStatus.completed);
    expect(updatedRequest.assignedDriverId, 'driver-001');
    expect(updatedRequest.assignedVehicleId, 'vehicle-001');
    expect(updatedRequest.completedByDriverId, 'driver-001');
    expect(updatedRequest.completedAt, completedAt);
  });

  test('copyWith can clear nullable assignment data', () {
    const driverInfo = DriverInfo(
      name: 'Ivan Ivanov',
      vehicle: 'Toyota Prius',
      licensePlate: 'CB1234AB',
      etaMinutes: 5,
    );

    final request = createRequest(
      assignedDriverId: 'driver-001',
      assignedVehicleId: 'vehicle-001',
      driverInfo: driverInfo,
    );

    final updatedRequest = request.copyWith(
      assignedDriverId: null,
      assignedVehicleId: null,
      driverInfo: null,
    );

    expect(updatedRequest.assignedDriverId, isNull);
    expect(updatedRequest.assignedVehicleId, isNull);
    expect(updatedRequest.driverInfo, isNull);
  });

  test('copyWith can clear completion data', () {
    final request = createRequest(
      completedByDriverId: 'driver-001',
      completedAt: DateTime(2026, 9, 26, 10, 45),
    );

    final updatedRequest = request.copyWith(
      completedByDriverId: null,
      completedAt: null,
    );

    expect(updatedRequest.completedByDriverId, isNull);
    expect(updatedRequest.completedAt, isNull);
  });
}
