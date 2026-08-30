import 'package:flutter_test/flutter_test.dart';

import 'package:taxi_app/models/ride_request_status.dart';

void main() {
  test('Ride request can be cancelled before ride starts', () {
    expect(
      RideRequestStatus.pending.canBeCancelled,
      isTrue,
    );

    expect(
      RideRequestStatus.accepted.canBeCancelled,
      isTrue,
    );

    expect(
      RideRequestStatus.driverArriving.canBeCancelled,
      isTrue,
    );
  });

  test('Ride request cannot be cancelled after ride starts', () {
    expect(
      RideRequestStatus.inProgress.canBeCancelled,
      isFalse,
    );

    expect(
      RideRequestStatus.completed.canBeCancelled,
      isFalse,
    );

    expect(
      RideRequestStatus.cancelled.canBeCancelled,
      isFalse,
    );
  });
}