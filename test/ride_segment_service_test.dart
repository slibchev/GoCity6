import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_app/models/ride_segment.dart';
import 'package:taxi_app/services/ride_segment_service.dart';
import 'package:taxi_app/services/pricing_calculator.dart';

void main() {
  group('Ride segment tariff switching', () {
    test('Day ride without tariff change', () {
      final segments = RideSegmentService.splitByTariffTime(
        startTime: DateTime(2026, 1, 1, 10, 0),
        endTime: DateTime(2026, 1, 1, 11, 0),
        totalKilometers: 10,
        totalWaitingMinutes: 5,
        intercity: false,
      );

      expect(segments.length, 1);
      expect(segments[0].tariffType, TariffType.day);
    });

    test('Night ride without tariff change', () {
      final segments = RideSegmentService.splitByTariffTime(
        startTime: DateTime(2026, 1, 1, 23, 0),
        endTime: DateTime(2026, 1, 2, 1, 0),
        totalKilometers: 10,
        totalWaitingMinutes: 5,
        intercity: false,
      );

      expect(segments.length, 1);
      expect(segments[0].tariffType, TariffType.night);
    });

    test('Ride crossing 22:00 splits into day and night', () {
      final segments = RideSegmentService.splitByTariffTime(
        startTime: DateTime(2026, 1, 1, 21, 55),
        endTime: DateTime(2026, 1, 1, 22, 20),
        totalKilometers: 10,
        totalWaitingMinutes: 5,
        intercity: false,
      );

      expect(segments.length, 2);

      expect(segments[0].tariffType, TariffType.day);
      expect(segments[0].startTime.hour, 21);
      expect(segments[0].endTime.hour, 22);

      expect(segments[1].tariffType, TariffType.night);
      expect(segments[1].startTime.hour, 22);
      expect(segments[1].endTime.hour, 22);
      expect(segments[1].endTime.minute, 20);
    });

    test('Ride crossing 06:00 splits into night and day', () {
      final segments = RideSegmentService.splitByTariffTime(
        startTime: DateTime(2026, 1, 2, 5, 50),
        endTime: DateTime(2026, 1, 2, 6, 10),
        totalKilometers: 10,
        totalWaitingMinutes: 5,
        intercity: false,
      );

      expect(segments.length, 2);

      expect(segments[0].tariffType, TariffType.night);
      expect(segments[0].startTime.hour, 5);
      expect(segments[0].endTime.hour, 6);

      expect(segments[1].tariffType, TariffType.day);
      expect(segments[1].startTime.hour, 6);
      expect(segments[1].endTime.hour, 6);
      expect(segments[1].endTime.minute, 10);
    });
    test('Day segment price is calculated with day tariff', () {
  final segment = RideSegment(
    startTime: DateTime(2026, 1, 1, 10, 0),
    endTime: DateTime(2026, 1, 1, 10, 30),
    kilometers: 10,
    waitingMinutes: 5,
    tariffType: TariffType.day,
    intercity: false,
  );

  final price = RideSegmentService.calculateSegmentPrice(segment);

  expect(price, 10.85);
});

test('Night segment price is calculated with night tariff', () {
  final segment = RideSegment(
    startTime: DateTime(2026, 1, 1, 23, 0),
    endTime: DateTime(2026, 1, 1, 23, 30),
    kilometers: 10,
    waitingMinutes: 5,
    tariffType: TariffType.night,
    intercity: false,
  );

  final price = RideSegmentService.calculateSegmentPrice(segment);

  expect(price, 12.05);
});
test('Ride price is the sum of all segment prices', () {
  final segments = [
    RideSegment(
      startTime: DateTime(2026, 1, 1, 10, 0),
      endTime: DateTime(2026, 1, 1, 10, 30),
      kilometers: 10,
      waitingMinutes: 5,
      tariffType: TariffType.day,
      intercity: false,
    ),
    RideSegment(
      startTime: DateTime(2026, 1, 1, 23, 0),
      endTime: DateTime(2026, 1, 1, 23, 30),
      kilometers: 10,
      waitingMinutes: 5,
      tariffType: TariffType.night,
      intercity: false,
    ),
  ];

  final price = RideSegmentService.calculateRidePrice(segments);

  expect(price, 22.90);
});
  });
}