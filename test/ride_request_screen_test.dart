import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taxi_app/localization/translations.dart';
import 'package:taxi_app/models/route_result.dart';
import 'package:taxi_app/screens/ride_request_screen.dart';
import 'package:taxi_app/services/route_service.dart';
import 'package:taxi_app/screens/ride_summary_screen.dart';

class FailingRouteService implements RouteService {
  @override
  Future<RouteResult> calculateRoute({
    required String pickup,
    required String destination,
  }) async {
    throw Exception('Route calculation failed');
  }
}
class SuccessfulRouteService implements RouteService {
  @override
  Future<RouteResult> calculateRoute({
    required String pickup,
    required String destination,
  }) async {
    return const RouteResult(
      distanceKm: 12.5,
      durationMinutes: 25,
      
    );
    
  }
}
class NightIntercityRouteService implements RouteService {
  @override
  Future<RouteResult> calculateRoute({
    required String pickup,
    required String destination,
  }) async {
    return const RouteResult(
      distanceKm: 10,
      durationMinutes: 20,
    );
  }
}

void main() {
  testWidgets(
    'RideRequestScreen handles route calculation error',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RideRequestScreen(
            routeService: FailingRouteService(),
          ),
        ),
      );

      final textFields = find.byType(TextField);

      await tester.enterText(
        textFields.at(0),
        'Pickup location',
      );

      await tester.enterText(
        textFields.at(1),
        'Destination location',
      );

      final confirmButton = find.byType(ElevatedButton);

final button = tester.widget<ElevatedButton>(
  confirmButton,
);

button.onPressed!();

await tester.pumpAndSettle();

      expect(
        find.text(AppTranslations.routeCalculationFailed),
        findsOneWidget,
      );

      final buttonAfterError = tester.widget<ElevatedButton>(
  confirmButton,
);

expect(buttonAfterError.onPressed, isNotNull);
    },
  );
  testWidgets(
  'RideRequestScreen passes route result to RideSummaryScreen',
  (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RideRequestScreen(
  routeService: SuccessfulRouteService(),
  now: () => DateTime(2026, 1, 1, 10, 0),
),
      ),
    );

    final textFields = find.byType(TextField);

    await tester.enterText(
      textFields.at(0),
      'Pickup location',
    );

    await tester.enterText(
      textFields.at(1),
      'Destination location',
    );

    final confirmButton = find.byType(ElevatedButton);

    final button = tester.widget<ElevatedButton>(
      confirmButton,
    );

    button.onPressed!();

    await tester.pumpAndSettle();

    expect(
      find.byType(RideSummaryScreen),
      findsOneWidget,
    );

    final summaryScreen = tester.widget<RideSummaryScreen>(
      find.byType(RideSummaryScreen),
    );

    expect(summaryScreen.routeResult, isNotNull);
    expect(summaryScreen.routeResult!.distanceKm, 12.5);
    expect(summaryScreen.routeResult!.durationMinutes, 25);
    expect(
  summaryScreen.estimatedPrice,
  closeTo(11.475, 0.001),
);
    expect(
  find.textContaining('12.5 km'),
  findsOneWidget,
);

expect(
  find.textContaining('25'),
  findsOneWidget,
);
final formattedPrice =
    summaryScreen.estimatedPrice!.toStringAsFixed(2);

expect(
  find.textContaining(formattedPrice),
  findsOneWidget,
);
  },
);
testWidgets(
  'RideRequestScreen calculates night intercity estimated price',
  (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RideRequestScreen(
          routeService: NightIntercityRouteService(),
          now: () => DateTime(2026, 1, 1, 23, 0),
        ),
      ),
    );

    final textFields = find.byType(TextField);

    await tester.enterText(
      textFields.at(0),
      'Pickup location',
    );

    await tester.enterText(
      textFields.at(1),
      'Destination location',
    );

    await tester.tap(
      find.text(AppTranslations.intercityRide),
    );

    await tester.pump();

    final confirmButton = find.byType(ElevatedButton);

    final button = tester.widget<ElevatedButton>(
      confirmButton,
    );

    button.onPressed!();

    await tester.pumpAndSettle();

    expect(
      find.byType(RideSummaryScreen),
      findsOneWidget,
    );

    final summaryScreen = tester.widget<RideSummaryScreen>(
      find.byType(RideSummaryScreen),
    );

    expect(
      summaryScreen.estimatedPrice,
      closeTo(13.20, 0.001),
    );

    final formattedPrice =
        summaryScreen.estimatedPrice!.toStringAsFixed(2);

    expect(
      find.textContaining(formattedPrice),
      findsOneWidget,
    );
  },
);
}