import '../models/ride_request_data.dart';

abstract interface class RideBonusDecisionService {
  Future<RideRequestData> acceptBonus(RideRequestData request);
  Future<RideRequestData> declineBonus(RideRequestData request);
}
