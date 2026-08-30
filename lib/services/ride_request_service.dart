import '../models/ride_request_data.dart';

abstract class RideRequestService {
  Future<RideRequestData> submitRequest(RideRequestData request);

  Future<RideRequestData> getRequestStatus(RideRequestData request);
  Future<RideRequestData> cancelRequest(RideRequestData request);

  Stream<RideRequestData> watchRequestStatus(RideRequestData request);
}
