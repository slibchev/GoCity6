class Tariff {
  final double initialFare;
  final double callOutFee;
  final double waitingPerMinute;
  final double cityPerKm;
  final double intercityPerKm;

  const Tariff({
    required this.initialFare,
    required this.callOutFee,
    required this.waitingPerMinute,
    required this.cityPerKm,
    required this.intercityPerKm,
  });
}

class PricingConfig {
  // Час на преминаване към дневна тарифа
  static const int dayStartHour = 6;

  // Час на преминаване към нощна тарифа
  static const int nightStartHour = 22;

  // Дневна тарифа
  static const Tariff dayTariff = Tariff(
    initialFare: 1.50,
    callOutFee: 0.60,
    waitingPerMinute: 0.25,
    cityPerKm: 0.75,
    intercityPerKm: 0.99,
  );

  // Нощна тарифа
  static const Tariff nightTariff = Tariff(
    initialFare: 1.70,
    callOutFee: 0.60,
    waitingPerMinute: 0.25,
    cityPerKm: 0.85,
    intercityPerKm: 1.09,
  );
}