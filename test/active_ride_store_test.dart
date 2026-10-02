import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxi_app/models/driver_info.dart';
import 'package:taxi_app/models/ride.dart';
import 'package:taxi_app/models/ride_request_data.dart';
import 'package:taxi_app/models/ride_request_status.dart';
import 'package:taxi_app/models/route_result.dart';
import 'package:taxi_app/services/active_ride_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saves and loads complete active ride snapshot', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = ActiveRideStore(preferences);

    final request = RideRequestData(
      requestId: 'ride-001',
      driverInfo: const DriverInfo(
        name: 'Ivan Ivanov',
        vehicle: 'Toyota Prius',
        licensePlate: 'CB1234AB',
        etaMinutes: 5,
        phoneNumber: '+359888123456',
      ),
      assignedDriverId: 'driver-001',
      assignedVehicleId: 'vehicle-001',
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 2,
      hasLuggage: true,
      paymentMethod: RidePaymentMethod.card,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 10, 2, 15, 30),
      status: RideRequestStatus.accepted,
      routeResult: const RouteResult(
        distanceKm: 4.25,
        durationMinutes: 11.5,
        pickupLatitude: 42.7001,
        pickupLongitude: 23.3201,
        destinationLatitude: 42.7102,
        destinationLongitude: 23.3302,
        encodedPolyline: 'encoded-polyline',
      ),
      estimatedPrice: 12.80,
      completedByDriverId: 'driver-001',
      completedAt: DateTime(2026, 10, 2, 15, 50),
    );

    await store.save(request);

    final loaded = store.load();

    expect(loaded, isNotNull);

    expect(loaded!.requestId, request.requestId);
    expect(loaded.assignedDriverId, request.assignedDriverId);
    expect(loaded.assignedVehicleId, request.assignedVehicleId);
    expect(loaded.pickup, request.pickup);
    expect(loaded.destination, request.destination);
    expect(loaded.passengers, request.passengers);
    expect(loaded.hasLuggage, request.hasLuggage);
    expect(loaded.paymentMethod, request.paymentMethod);
    expect(loaded.rideType, request.rideType);
    expect(loaded.requestedAt, request.requestedAt);
    expect(loaded.status, request.status);
    expect(loaded.estimatedPrice, request.estimatedPrice);
    expect(loaded.completedByDriverId, request.completedByDriverId);
    expect(loaded.completedAt, request.completedAt);

    expect(loaded.driverInfo, isNotNull);
    expect(loaded.driverInfo!.name, request.driverInfo!.name);
    expect(loaded.driverInfo!.vehicle, request.driverInfo!.vehicle);
    expect(loaded.driverInfo!.licensePlate, request.driverInfo!.licensePlate);
    expect(loaded.driverInfo!.etaMinutes, request.driverInfo!.etaMinutes);
    expect(loaded.driverInfo!.phoneNumber, request.driverInfo!.phoneNumber);

    expect(loaded.routeResult, isNotNull);
    expect(loaded.routeResult!.distanceKm, request.routeResult!.distanceKm);
    expect(
      loaded.routeResult!.durationMinutes,
      request.routeResult!.durationMinutes,
    );
    expect(
      loaded.routeResult!.pickupLatitude,
      request.routeResult!.pickupLatitude,
    );
    expect(
      loaded.routeResult!.pickupLongitude,
      request.routeResult!.pickupLongitude,
    );
    expect(
      loaded.routeResult!.destinationLatitude,
      request.routeResult!.destinationLatitude,
    );
    expect(
      loaded.routeResult!.destinationLongitude,
      request.routeResult!.destinationLongitude,
    );
    expect(
      loaded.routeResult!.encodedPolyline,
      request.routeResult!.encodedPolyline,
    );
  });

  test('clear removes stored active ride', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = ActiveRideStore(preferences);

    final request = RideRequestData(
      requestId: 'ride-002',
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 1,
      paymentMethod: RidePaymentMethod.cash,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 10, 2, 16),
      status: RideRequestStatus.waitingForVehicle,
    );

    await store.save(request);

    expect(store.load(), isNotNull);

    await store.clear();

    expect(store.load(), isNull);
  });

  test('load returns null for invalid stored data', () async {
    SharedPreferences.setMockInitialValues({
      'activeRide': '{"status":"not-a-real-status"}',
    });

    final preferences = await SharedPreferences.getInstance();
    final store = ActiveRideStore(preferences);

    expect(store.load(), isNull);
  });
}
