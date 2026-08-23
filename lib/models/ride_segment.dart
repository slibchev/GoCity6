import 'package:taxi_app/models/tariff_type.dart';
import 'tariff_type.dart';

class RideSegment {
  final DateTime startTime;
  final DateTime endTime;

  final double kilometers;
  final double waitingMinutes;

  final TariffType tariffType;
  final bool intercity;

  const RideSegment({
    required this.startTime,
    required this.endTime,
    required this.kilometers,
    required this.waitingMinutes,
    required this.tariffType,
    required this.intercity,
  });
}