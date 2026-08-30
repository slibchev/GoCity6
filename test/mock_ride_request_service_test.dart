import 'package:flutter_test/flutter_test.dart';

import 'package:taxi_app/models/ride.dart';
import 'package:taxi_app/models/ride_request_data.dart';
import 'package:taxi_app/models/ride_request_status.dart';
import 'support/mock_ride_request_service.dart';

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
    expect(
  submittedRequest.requestId,
  'mock-request-001',
);

    final updatedRequest = await service.getRequestStatus(
      submittedRequest,
    );

    expect(
      updatedRequest.status,
      RideRequestStatus.accepted,
    );
  });
  test('MockRideRequestService streams full ride lifecycle', () async {
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

  final statuses = await service
      .watchRequestStatus(request)
      .map((request) => request.status)
      .toList();

  expect(
  statuses,
  [
    RideRequestStatus.pending,
    RideRequestStatus.accepted,
    RideRequestStatus.driverArriving,
    RideRequestStatus.inProgress,
    RideRequestStatus.completed,
  ],
);
});
test(
  'MockRideRequestService advances through full ride lifecycle',
  () async {
    final service = MockRideRequestService();

    RideRequestData request = RideRequestData(
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 1,
      paymentMethod: RidePaymentMethod.cash,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 1, 1, 10, 0),
      status: RideRequestStatus.pending,
    );

    request = await service.getRequestStatus(request);

    expect(
      request.status,
      RideRequestStatus.accepted,
    );

    request = await service.getRequestStatus(request);

    expect(
      request.status,
      RideRequestStatus.driverArriving,
    );

    request = await service.getRequestStatus(request);

    expect(
      request.status,
      RideRequestStatus.inProgress,
    );

    request = await service.getRequestStatus(request);

    expect(
      request.status,
      RideRequestStatus.completed,
    );

    request = await service.getRequestStatus(request);

    expect(
      request.status,
      RideRequestStatus.completed,
    );
  },
);
test(
  'MockRideRequestService keeps cancelled ride cancelled',
  () async {
    final service = MockRideRequestService();

    final request = RideRequestData(
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 1,
      paymentMethod: RidePaymentMethod.cash,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 1, 1, 10, 0),
      status: RideRequestStatus.cancelled,
    );

    final updatedRequest = await service.getRequestStatus(
      request,
    );

    expect(
      updatedRequest.status,
      RideRequestStatus.cancelled,
    );
  },
);
test(
  'MockRideRequestService cancels pending ride request',
  () async {
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

    final cancelledRequest = await service.cancelRequest(
      request,
    );

    expect(
      cancelledRequest.status,
      RideRequestStatus.cancelled,
    );
  },
);
test(
  'MockRideRequestService does not cancel ride in progress',
  () async {
    final service = MockRideRequestService();

    final request = RideRequestData(
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 1,
      paymentMethod: RidePaymentMethod.cash,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 1, 1, 10, 0),
      status: RideRequestStatus.inProgress,
    );

    final updatedRequest = await service.cancelRequest(
      request,
    );

    expect(
      updatedRequest.status,
      RideRequestStatus.inProgress,
    );
  },
);
}