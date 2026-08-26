import 'package:flutter_test/flutter_test.dart';

import 'package:taxi_app/models/ride.dart';
import 'package:taxi_app/models/ride_request_data.dart';
import 'package:taxi_app/models/ride_request_status.dart';
import 'package:taxi_app/services/mock_ride_request_service.dart';

void main() {
  test('MockRideRequestService changes pending request to accepted', () async {
    final service = MockRideRequestService();

    final request = RideRequestData(
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 1,
      paymentMethod: RidePaymentMethod.cash,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 1, 1, 10, 0),
      status: RideRequestStatus.pending,
    );

    final submittedRequest = await service.submitRequest(
      request,
    );

    expect(
      submittedRequest.status,
      RideRequestStatus.pending,
    );

    final updatedRequest = await service.getRequestStatus(
      submittedRequest,
    );

    expect(
      updatedRequest.status,
      RideRequestStatus.accepted,
    );
  });
}