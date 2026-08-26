import 'package:flutter_test/flutter_test.dart';

import 'package:taxi_app/models/ride.dart';
import 'package:taxi_app/models/ride_request_data.dart';
import 'package:taxi_app/models/ride_request_status.dart';

void main() {
  test('RideRequestData copyWith changes status and keeps other data', () {
    final request = RideRequestData(
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

    expect(
      acceptedRequest.status,
      RideRequestStatus.accepted,
    );

    expect(
      acceptedRequest.pickup,
      request.pickup,
    );

    expect(
      acceptedRequest.destination,
      request.destination,
    );

    expect(
      acceptedRequest.paymentMethod,
      request.paymentMethod,
    );

    expect(
      acceptedRequest.estimatedPrice,
      request.estimatedPrice,
    );
  });
}