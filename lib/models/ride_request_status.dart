enum RideRequestStatus {
  pending,
  accepted,
  driverArriving,
  inProgress,
  completed,
  cancelled,

  // The customer is waiting because there is currently
  // no available vehicle.
  waitingForVehicle,

  // A driver has selected this ride as the next ride,
  // but may still be completing the current one.
  reserved,
}

extension RideRequestStatusX on RideRequestStatus {
  bool get canBeCancelled {
    switch (this) {
      case RideRequestStatus.waitingForVehicle:
      case RideRequestStatus.pending:
      case RideRequestStatus.reserved:
      case RideRequestStatus.accepted:
      case RideRequestStatus.driverArriving:
        return true;

      case RideRequestStatus.inProgress:
      case RideRequestStatus.completed:
      case RideRequestStatus.cancelled:
        return false;
    }
  }
}