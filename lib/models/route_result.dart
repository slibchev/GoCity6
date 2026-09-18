class RouteResult {
  final double distanceKm;
  final double durationMinutes;

  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? destinationLatitude;
  final double? destinationLongitude;

  final String? encodedPolyline;

  const RouteResult({
    required this.distanceKm,
    required this.durationMinutes,
    this.pickupLatitude,
    this.pickupLongitude,
    this.destinationLatitude,
    this.destinationLongitude,
    this.encodedPolyline,
  });
}