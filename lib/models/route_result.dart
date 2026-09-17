class RouteResult {
  final double distanceKm;
  final double durationMinutes;

  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? destinationLatitude;
  final double? destinationLongitude;

  const RouteResult({
    required this.distanceKm,
    required this.durationMinutes,
    this.pickupLatitude,
    this.pickupLongitude,
    this.destinationLatitude,
    this.destinationLongitude,
  });
}