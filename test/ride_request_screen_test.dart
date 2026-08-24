import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taxi_app/localization/translations.dart';
import 'package:taxi_app/models/route_result.dart';
import 'package:taxi_app/screens/ride_request_screen.dart';
import 'package:taxi_app/services/route_service.dart';

class FailingRouteService implements RouteService {
  @override
  Future<RouteResult> calculateRoute({
    required String pickup,
    required String destination,
  }) async {
    throw Exception('Route calculation failed');
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
}