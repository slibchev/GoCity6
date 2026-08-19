import '../config/pricing_config.dart';
import '../models/ride_segment.dart';
import 'pricing_calculator.dart';

class RideSegmentService {
  static List<RideSegment> splitByTariffTime({
    required DateTime startTime,
    required DateTime endTime,
    required double totalKilometers,
    required double totalWaitingMinutes,
    required bool intercity,
  }) {
    if (!endTime.isAfter(startTime)) {
      return [];
    }

    final segments = <RideSegment>[];

    DateTime currentStart = startTime;

    while (currentStart.isBefore(endTime)) {
      final tariffType =
          PricingCalculator.getTariffType(currentStart);

      final currentEnd = _getSegmentEnd(
        currentStart,
        endTime,
      );

      segments.add(
        RideSegment(
          startTime: currentStart,
          endTime: currentEnd,
          kilometers: 0,
          waitingMinutes: 0,
          tariffType: tariffType,
          intercity: intercity,
        ),
      );

      currentStart = currentEnd;
    }

    return segments;
  }
  static double calculateSegmentPrice(RideSegment segment) {
  final tariff = PricingCalculator.getTariff(segment.tariffType);


  return PricingCalculator.calculateSegmentPrice(
    tariff: tariff,
    kilometers: segment.kilometers,
    waitingMinutes: segment.waitingMinutes,
    intercity: segment.intercity,
  );
}
static double calculateRidePrice(List<RideSegment> segments) {
  double totalPrice = 0;

  for (final segment in segments) {
    totalPrice += calculateSegmentPrice(segment);
  }

  return totalPrice;
}

  static DateTime _getSegmentEnd(
    DateTime currentStart,
    DateTime rideEnd,
  ) {
    final dayChange = DateTime(
      currentStart.year,
      currentStart.month,
      currentStart.day,
      PricingConfig.dayStartHour,
    );

    final nightChange = DateTime(
      currentStart.year,
      currentStart.month,
      currentStart.day,
      PricingConfig.nightStartHour,
    );

    DateTime nextChange;

    if (currentStart.hour < PricingConfig.dayStartHour) {
      nextChange = dayChange;
    } else if (currentStart.hour < PricingConfig.nightStartHour) {
      nextChange = nightChange;
    } else {
      nextChange = dayChange.add(
        const Duration(days: 1),
      );
    }

    if (nextChange.isAfter(rideEnd)) {
      return rideEnd;
    }

    return nextChange;
  }
}