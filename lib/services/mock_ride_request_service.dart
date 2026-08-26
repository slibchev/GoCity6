import '../models/ride_request_data.dart';
import '../models/ride_request_status.dart';
import 'ride_request_service.dart';

class MockRideRequestService implements RideRequestService {
  @override
  Future<RideRequestData> submitRequest(
    RideRequestData request,
  ) async {
    return request.copyWith(
      status: RideRequestStatus.pending,
    );
  }

  @override
  Future<RideRequestData> getRequestStatus(
    RideRequestData request,
  ) async {
    if (request.status == RideRequestStatus.pending) {
      return request.copyWith(
        status: RideRequestStatus.accepted,
      );
    }

    return request;
  }
}