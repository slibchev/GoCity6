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
  switch (request.status) {
    case RideRequestStatus.pending:
      return request.copyWith(
        status: RideRequestStatus.accepted,
      );

    case RideRequestStatus.accepted:
      return request.copyWith(
        status: RideRequestStatus.driverArriving,
      );

    case RideRequestStatus.driverArriving:
      return request.copyWith(
        status: RideRequestStatus.inProgress,
      );

    case RideRequestStatus.inProgress:
      return request.copyWith(
        status: RideRequestStatus.completed,
      );

    case RideRequestStatus.completed:
    case RideRequestStatus.cancelled:
      return request;
  }
}

  @override
Stream<RideRequestData> watchRequestStatus(
  RideRequestData request,
) async* {
  RideRequestData currentRequest = request;

  yield currentRequest;

  while (currentRequest.status != RideRequestStatus.completed &&
      currentRequest.status != RideRequestStatus.cancelled) {
    currentRequest = await getRequestStatus(
      currentRequest,
    );

    yield currentRequest;
  }
}
}