class DriverInfo {
  final String name;
  final String vehicle;
  final String licensePlate;
  final int? etaMinutes;

  const DriverInfo({
    required this.name,
    required this.vehicle,
    required this.licensePlate,
    this.etaMinutes,
  });
}