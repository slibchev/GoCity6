import '../models/ride_request_data.dart';
import '../models/ride_request_status.dart';
import 'ride_request_service.dart';
import '../models/driver_info.dart';

class MockRideRequestService implements RideRequestService {
  @override
  Future<RideRequestData> submitRequest(RideRequestData request) async {
    return request.copyWith(
      requestId: request.requestId ?? 'mock-request-001',
      status: RideRequestStatus.pending,
    );
  }

  @override
  Future<RideRequestData> getRequestStatus(RideRequestData request) async {
    switch (request.status) {
      case RideRequestStatus.waitingForVehicle:
        return request.copyWith(
          status: RideRequestStatus.reserved,
          driverInfo: const DriverInfo(
            name: 'Ivan Ivanov',
            vehicle: 'Toyota Prius',
            licensePlate: 'CB1234AB',
            etaMinutes: 5,
            phoneNumber: '+359888123456',
          ),
        );

      case RideRequestStatus.pending:
        return request.copyWith(
          status: RideRequestStatus.accepted,
          driverInfo: const DriverInfo(
            name: 'Ivan Ivanov',
            vehicle: 'Toyota Prius',
            licensePlate: 'CB1234AB',
            etaMinutes: 5,
            phoneNumber: '+359888123456',
          ),
        );

      case RideRequestStatus.reserved:
        return request.copyWith(status: RideRequestStatus.accepted);

      case RideRequestStatus.accepted:
        return request.copyWith(status: RideRequestStatus.driverArriving);

      case RideRequestStatus.driverArriving:
        return request.copyWith(status: RideRequestStatus.inProgress);

      case RideRequestStatus.inProgress:
        return request.copyWith(status: RideRequestStatus.completed);

      case RideRequestStatus.completed:
      case RideRequestStatus.cancelled:
        return request;
    }
  }

  @override
  Future<RideRequestData> cancelRequest(RideRequestData request) async {
    if (!request.status.canBeCancelled) {
      return request;
    }

    return request.copyWith(status: RideRequestStatus.cancelled);
  }

  @override
  Stream<RideRequestData> watchRequestStatus(RideRequestData request) async* {
    RideRequestData currentRequest = request;

    yield currentRequest;

    while (currentRequest.status != RideRequestStatus.completed &&
        currentRequest.status != RideRequestStatus.cancelled) {
      await Future<void>.delayed(const Duration(seconds: 3));

      currentRequest = await getRequestStatus(currentRequest);

      yield currentRequest;
    }
  }
}