import 'package:taxi_app/config/pricing_config.dart';
import 'package:taxi_app/models/tariff_type.dart';

class PricingCalculator {
  static Tariff getTariff(TariffType type) {
    if (type == TariffType.day) {
      return PricingConfig.dayTariff;
    }

    return PricingConfig.nightTariff;
  }

  static TariffType getTariffType(DateTime time) {
    final hour = time.hour;

    if (hour >= PricingConfig.nightStartHour ||
        hour < PricingConfig.dayStartHour) {
      return TariffType.night;
    }

    return TariffType.day;
  }

  static double calculateUsagePrice({
    required Tariff tariff,
    required double kilometers,
    required double waitingMinutes,
    bool intercity = false,
  }) {
    final pricePerKm =
        intercity ? tariff.intercityPerKm : tariff.cityPerKm;

    return (kilometers * pricePerKm) +
        (waitingMinutes * tariff.waitingPerMinute);
  }

  static double calculateSegmentPrice({
    required Tariff tariff,
    required double kilometers,
    required double waitingMinutes,
    bool intercity = false,
  }) {
    return tariff.initialFare +
        tariff.callOutFee +
        calculateUsagePrice(
          tariff: tariff,
          kilometers: kilometers,
          waitingMinutes: waitingMinutes,
          intercity: intercity,
        );
  }
  static double calculateEstimatedPrice({
  required DateTime startTime,
  required double kilometers,
  required bool intercity,
}) {
  final tariffType = getTariffType(startTime);
  final tariff = getTariff(tariffType);

  return calculateSegmentPrice(
    tariff: tariff,
    kilometers: kilometers,
    waitingMinutes: 0,
    intercity: intercity,
  );
}
}