import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_app/models/ride.dart';
import 'package:taxi_app/models/ride_request_data.dart';
import 'package:taxi_app/models/ride_request_status.dart';
import 'package:taxi_app/models/driver_info.dart';

void main() {
  test('RideRequestData copyWith changes status and keeps other data', () {
    final request = RideRequestData(
      requestId: 'request-123',
      driverInfo: const DriverInfo(
        name: 'Test Driver',
        vehicle: 'Dacia Jogger',
        licensePlate: 'CB 1234 AB',
        etaMinutes: 4,
        phoneNumber: '+359888123456',
      ),
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 2,
      paymentMethod: RidePaymentMethod.card,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 1, 1, 10, 0),
      status: RideRequestStatus.pending,
      estimatedPrice: 10.50,
    );

    final acceptedRequest = request.copyWith(
      status: RideRequestStatus.accepted,
    );

    expect(acceptedRequest.status, RideRequestStatus.accepted);

    expect(acceptedRequest.pickup, request.pickup);

    expect(acceptedRequest.destination, request.destination);

    expect(acceptedRequest.paymentMethod, request.paymentMethod);

    expect(acceptedRequest.estimatedPrice, request.estimatedPrice);
    expect(acceptedRequest.requestId, request.requestId);
    expect(acceptedRequest.driverInfo, request.driverInfo);
    expect(acceptedRequest.driverInfo?.phoneNumber, '+359888123456');
  });
}
