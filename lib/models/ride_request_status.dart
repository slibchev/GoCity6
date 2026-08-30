enum RideRequestStatus {
  pending,
  accepted,
  driverArriving,
  inProgress,
  completed,
  cancelled,
}
extension RideRequestStatusX on RideRequestStatus {
  bool get canBeCancelled {
    switch (this) {
      case RideRequestStatus.pending:
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