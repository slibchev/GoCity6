import 'package:taxi_app/models/ride_request_data.dart';
import 'package:taxi_app/models/ride_request_status.dart';
import 'package:taxi_app/services/ride_request_service.dart';

class MockRideRequestService implements RideRequestService {
  @override
Future<RideRequestData> submitRequest(
  RideRequestData request,
) async {
  return request.copyWith(
    requestId: request.requestId ?? 'mock-request-001',
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

  @override
  Stream<RideRequestData> watchRequestStatus(
    RideRequestData request,
  ) async* {
    yield request;

    if (request.status == RideRequestStatus.pending) {
      yield request.copyWith(
        status: RideRequestStatus.accepted,
      );
    }
  }
}