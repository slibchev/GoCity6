import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_app/services/pricing_calculator.dart';

void main() {
  group('Tariff time switching', () {
    test('05:59 should be night tariff', () {
      final time = DateTime(2026, 1, 1, 5, 59);

      expect(
        PricingCalculator.getTariffType(time),
        TariffType.night,
      );
    });

    test('06:00 should be day tariff', () {
      final time = DateTime(2026, 1, 1, 6, 0);

      expect(
        PricingCalculator.getTariffType(time),
        TariffType.day,
      );
    });

    test('21:59 should be day tariff', () {
      final time = DateTime(2026, 1, 1, 21, 59);

      expect(
        PricingCalculator.getTariffType(time),
        TariffType.day,
      );
    });

    test('22:00 should be night tariff', () {
      final time = DateTime(2026, 1, 1, 22, 0);

      expect(
        PricingCalculator.getTariffType(time),
        TariffType.night,
      );
    });
  });
  group('Price calculation', () {
    test('Day city ride should calculate correctly', () {
      final price = PricingCalculator.calculateSegmentPrice(
        tariff: PricingCalculator.getTariff(TariffType.day),
        kilometers: 10,
        waitingMinutes: 5,
      );

      expect(price, 10.85);
    });

    test('Day intercity ride should calculate correctly', () {
      final price = PricingCalculator.calculateSegmentPrice(
        tariff: PricingCalculator.getTariff(TariffType.day),
        kilometers: 10,
        waitingMinutes: 5,
        intercity: true,
      );

      expect(price, 13.25);
    });

    test('Night city ride should calculate correctly', () {
      final price = PricingCalculator.calculateSegmentPrice(
        tariff: PricingCalculator.getTariff(TariffType.night),
        kilometers: 10,
        waitingMinutes: 5,
      );

      expect(price, 12.05);
    });

    test('Night intercity ride should calculate correctly', () {
      final price = PricingCalculator.calculateSegmentPrice(
        tariff: PricingCalculator.getTariff(TariffType.night),
        kilometers: 10,
        waitingMinutes: 5,
        intercity: true,
      );

      expect(price, 14.45);
    });
  });
}