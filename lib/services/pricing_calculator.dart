import '../config/pricing_config.dart';

enum TariffType {
  day,
  night,
}

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

  static double calculateSegmentPrice({
    required Tariff tariff,
    required double kilometers,
    required double waitingMinutes,
    bool intercity = false,
  }) {
    final pricePerKm = intercity
        ? tariff.intercityPerKm
        : tariff.cityPerKm;

    return tariff.initialFare +
        tariff.callOutFee +
        (kilometers * pricePerKm) +
        (waitingMinutes * tariff.waitingPerMinute);
  }
}