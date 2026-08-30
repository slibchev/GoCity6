import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_app/localization/translations.dart';
import 'package:taxi_app/models/ride.dart';
import 'package:taxi_app/models/ride_request_data.dart';
import 'package:taxi_app/models/ride_request_status.dart';
import 'package:taxi_app/screens/ride_confirmation_screen.dart';
import 'support/mock_ride_request_service.dart';
import 'package:taxi_app/models/driver_info.dart';
import 'package:taxi_app/services/ride_request_service.dart';

class CancelTestRideRequestService implements RideRequestService {
  bool cancelCalled = false;

  @override
  Future<RideRequestData> submitRequest(RideRequestData request) async {
    return request;
  }

  @override
  Future<RideRequestData> getRequestStatus(RideRequestData request) async {
    return request;
  }

  @override
  Future<RideRequestData> cancelRequest(RideRequestData request) async {
    cancelCalled = true;

    return request.copyWith(
      status: RideRequestStatus.cancelled,
    );
  }

  @override
  Stream<RideRequestData> watchRequestStatus(RideRequestData request) {
    return const Stream<RideRequestData>.empty();
  }
}

void main() {
  testWidgets('RideConfirmationScreen shows pending status', (
    WidgetTester tester,
  ) async {
    final request = RideRequestData(
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 1,
      paymentMethod: RidePaymentMethod.cash,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 1, 1, 10, 0),
      status: RideRequestStatus.pending,
      estimatedPrice: 10.50,
    );

    await tester.pumpWidget(
      MaterialApp(home: RideConfirmationScreen(request: request)),
    );

    expect(find.text(AppTranslations.rideRequestSent), findsOneWidget);

    expect(
      find.text(AppTranslations.waitingForDriverConfirmation),
      findsOneWidget,
    );
  });

  testWidgets('RideConfirmationScreen shows accepted status', (
    WidgetTester tester,
  ) async {
    final request = RideRequestData(
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 1,
      paymentMethod: RidePaymentMethod.cash,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 1, 1, 10, 0),
      status: RideRequestStatus.accepted,
      estimatedPrice: 10.50,
    );

    await tester.pumpWidget(
      MaterialApp(home: RideConfirmationScreen(request: request)),
    );

    expect(find.text(AppTranslations.rideAccepted), findsWidgets);
  });

  testWidgets('RideConfirmationScreen updates through stream to completed', (
    WidgetTester tester,
  ) async {
    final request = RideRequestData(
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 1,
      paymentMethod: RidePaymentMethod.cash,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 1, 1, 10, 0),
      status: RideRequestStatus.pending,
      estimatedPrice: 10.50,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RideConfirmationScreen(
          request: request,
          rideRequestService: MockRideRequestService(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(AppTranslations.rideCompleted), findsWidgets);
  });

  testWidgets('RideConfirmationScreen shows driver arriving status', (
    WidgetTester tester,
  ) async {
    final request = RideRequestData(
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 1,
      paymentMethod: RidePaymentMethod.cash,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 1, 1, 10, 0),
      status: RideRequestStatus.driverArriving,
      estimatedPrice: 10.50,
    );

    await tester.pumpWidget(
      MaterialApp(home: RideConfirmationScreen(request: request)),
    );

    expect(find.text(AppTranslations.driverArriving), findsWidgets);
  });

  testWidgets('RideConfirmationScreen shows ride in progress status', (
    WidgetTester tester,
  ) async {
    final request = RideRequestData(
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 1,
      paymentMethod: RidePaymentMethod.cash,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 1, 1, 10, 0),
      status: RideRequestStatus.inProgress,
      estimatedPrice: 10.50,
    );

    await tester.pumpWidget(
      MaterialApp(home: RideConfirmationScreen(request: request)),
    );

    expect(find.text(AppTranslations.rideInProgress), findsWidgets);
  });

  testWidgets('RideConfirmationScreen shows completed status', (
    WidgetTester tester,
  ) async {
    final request = RideRequestData(
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 1,
      paymentMethod: RidePaymentMethod.cash,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 1, 1, 10, 0),
      status: RideRequestStatus.completed,
      estimatedPrice: 10.50,
    );

    await tester.pumpWidget(
      MaterialApp(home: RideConfirmationScreen(request: request)),
    );

    expect(find.text(AppTranslations.rideCompleted), findsWidgets);
  });

  testWidgets('RideConfirmationScreen shows cancelled status', (
    WidgetTester tester,
  ) async {
    final request = RideRequestData(
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 1,
      paymentMethod: RidePaymentMethod.cash,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 1, 1, 10, 0),
      status: RideRequestStatus.cancelled,
      estimatedPrice: 10.50,
    );

    await tester.pumpWidget(
      MaterialApp(home: RideConfirmationScreen(request: request)),
    );

    expect(find.text(AppTranslations.rideCancelled), findsWidgets);
  });

  testWidgets(
    'RideConfirmationScreen shows red cancel icon for cancelled ride',
    (WidgetTester tester) async {
      final request = RideRequestData(
        pickup: 'Pickup',
        destination: 'Destination',
        passengers: 1,
        paymentMethod: RidePaymentMethod.cash,
        rideType: RideType.city,
        requestedAt: DateTime(2026, 1, 1, 10, 0),
        status: RideRequestStatus.cancelled,
        estimatedPrice: 10.50,
      );

      await tester.pumpWidget(
        MaterialApp(home: RideConfirmationScreen(request: request)),
      );

      expect(find.byIcon(Icons.cancel), findsOneWidget);

      final icon = tester.widget<Icon>(find.byIcon(Icons.cancel));

      expect(icon.color, Colors.red);
    },
  );

  testWidgets('RideConfirmationScreen shows taxi icon for driver arriving', (
    WidgetTester tester,
  ) async {
    final request = RideRequestData(
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 1,
      paymentMethod: RidePaymentMethod.cash,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 1, 1, 10, 0),
      status: RideRequestStatus.driverArriving,
      estimatedPrice: 10.50,
    );

    await tester.pumpWidget(
      MaterialApp(home: RideConfirmationScreen(request: request)),
    );

    expect(find.byIcon(Icons.local_taxi), findsOneWidget);

    final icon = tester.widget<Icon>(find.byIcon(Icons.local_taxi));

    expect(icon.color, Colors.blue);
  });
  testWidgets(
    'RideConfirmationScreen shows driver information when driver is arriving',
    (WidgetTester tester) async {
      final request = RideRequestData(
        pickup: 'Pickup',
        destination: 'Destination',
        passengers: 1,
        paymentMethod: RidePaymentMethod.cash,
        rideType: RideType.city,
        requestedAt: DateTime(2026, 1, 1, 10, 0),
        status: RideRequestStatus.driverArriving,
        estimatedPrice: 10.50,
        driverInfo: const DriverInfo(
          name: 'Test Driver',
          vehicle: 'Dacia Jogger',
          licensePlate: 'CB 1234 AB',
          etaMinutes: 4,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: RideConfirmationScreen(request: request)),
      );

      expect(find.textContaining('Test Driver'), findsOneWidget);

      expect(find.textContaining('Dacia Jogger'), findsOneWidget);

      expect(find.textContaining('CB 1234 AB'), findsOneWidget);

      expect(find.textContaining('4'), findsWidgets);
    },
  );
  testWidgets(
    'RideConfirmationScreen hides driver information outside driver arriving status',
    (WidgetTester tester) async {
      final request = RideRequestData(
        pickup: 'Pickup',
        destination: 'Destination',
        passengers: 1,
        paymentMethod: RidePaymentMethod.cash,
        rideType: RideType.city,
        requestedAt: DateTime(2026, 1, 1, 10, 0),
        status: RideRequestStatus.completed,
        estimatedPrice: 10.50,
        driverInfo: const DriverInfo(
          name: 'Test Driver',
          vehicle: 'Dacia Jogger',
          licensePlate: 'CB 1234 AB',
          etaMinutes: 4,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: RideConfirmationScreen(request: request)),
      );

      expect(find.textContaining('Test Driver'), findsNothing);

      expect(find.textContaining('Dacia Jogger'), findsNothing);

      expect(find.textContaining('CB 1234 AB'), findsNothing);
    },
  );
  testWidgets(
    'RideConfirmationScreen shows call driver button when phone number exists',
    (WidgetTester tester) async {
      final request = RideRequestData(
        pickup: 'Pickup',
        destination: 'Destination',
        passengers: 1,
        paymentMethod: RidePaymentMethod.cash,
        rideType: RideType.city,
        requestedAt: DateTime(2026, 1, 1, 10, 0),
        status: RideRequestStatus.driverArriving,
        estimatedPrice: 10.50,
        driverInfo: const DriverInfo(
          name: 'Test Driver',
          vehicle: 'Dacia Jogger',
          licensePlate: 'CB 1234 AB',
          etaMinutes: 4,
          phoneNumber: '+359888123456',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: RideConfirmationScreen(request: request)),
      );

      expect(find.text(AppTranslations.callDriver), findsOneWidget);

      expect(find.byIcon(Icons.phone), findsOneWidget);
    },
  );
  testWidgets(
    'RideConfirmationScreen hides call driver button when phone number is missing',
    (WidgetTester tester) async {
      final request = RideRequestData(
        pickup: 'Pickup',
        destination: 'Destination',
        passengers: 1,
        paymentMethod: RidePaymentMethod.cash,
        rideType: RideType.city,
        requestedAt: DateTime(2026, 1, 1, 10, 0),
        status: RideRequestStatus.driverArriving,
        estimatedPrice: 10.50,
        driverInfo: const DriverInfo(
          name: 'Test Driver',
          vehicle: 'Dacia Jogger',
          licensePlate: 'CB 1234 AB',
          etaMinutes: 4,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: RideConfirmationScreen(request: request)),
      );

      expect(find.text(AppTranslations.callDriver), findsNothing);

      expect(find.byIcon(Icons.phone), findsNothing);
    },
  );
  testWidgets('RideConfirmationScreen shows error when phone launcher fails', (
    WidgetTester tester,
  ) async {
    final request = RideRequestData(
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 1,
      paymentMethod: RidePaymentMethod.cash,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 1, 1, 10, 0),
      status: RideRequestStatus.driverArriving,
      estimatedPrice: 10.50,
      driverInfo: const DriverInfo(
        name: 'Test Driver',
        vehicle: 'Dacia Jogger',
        licensePlate: 'CB 1234 AB',
        etaMinutes: 4,
        phoneNumber: '+359888123456',
      ),
    );

    Future<bool> failingLauncher(Uri uri) async {
      return false;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: RideConfirmationScreen(
          request: request,
          phoneLauncher: failingLauncher,
        ),
      ),
    );

    await tester.tap(find.text(AppTranslations.callDriver));

    await tester.pump();

    expect(find.text(AppTranslations.callDriverFailed), findsOneWidget);
  });
  testWidgets('RideConfirmationScreen shows error when phone launcher throws', (
    WidgetTester tester,
  ) async {
    final request = RideRequestData(
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 1,
      paymentMethod: RidePaymentMethod.cash,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 1, 1, 10, 0),
      status: RideRequestStatus.driverArriving,
      estimatedPrice: 10.50,
      driverInfo: const DriverInfo(
        name: 'Test Driver',
        vehicle: 'Dacia Jogger',
        licensePlate: 'CB 1234 AB',
        etaMinutes: 4,
        phoneNumber: '+359888123456',
      ),
    );

    Future<bool> throwingLauncher(Uri uri) async {
      throw Exception('Launch failed');
    }

    await tester.pumpWidget(
      MaterialApp(
        home: RideConfirmationScreen(
          request: request,
          phoneLauncher: throwingLauncher,
        ),
      ),
    );

    await tester.tap(find.text(AppTranslations.callDriver));

    await tester.pump();

    expect(find.text(AppTranslations.callDriverFailed), findsOneWidget);
  });
  testWidgets('RideConfirmationScreen launches correct phone number', (
    WidgetTester tester,
  ) async {
    Uri? launchedUri;

    final request = RideRequestData(
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 1,
      paymentMethod: RidePaymentMethod.cash,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 1, 1, 10, 0),
      status: RideRequestStatus.driverArriving,
      estimatedPrice: 10.50,
      driverInfo: const DriverInfo(
        name: 'Test Driver',
        vehicle: 'Dacia Jogger',
        licensePlate: 'CB 1234 AB',
        etaMinutes: 4,
        phoneNumber: '+359888123456',
      ),
    );

    Future<bool> successfulLauncher(Uri uri) async {
      launchedUri = uri;
      return true;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: RideConfirmationScreen(
          request: request,
          phoneLauncher: successfulLauncher,
        ),
      ),
    );

    await tester.tap(find.text(AppTranslations.callDriver));

    await tester.pump();

    expect(launchedUri, isNotNull);

    expect(launchedUri!.scheme, 'tel');

    expect(launchedUri!.path, '+359888123456');

    expect(find.text(AppTranslations.callDriverFailed), findsNothing);
  });
  testWidgets('RideConfirmationScreen shows cancel button before ride starts', (
    WidgetTester tester,
  ) async {
    final request = RideRequestData(
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 1,
      paymentMethod: RidePaymentMethod.cash,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 1, 1, 10, 0),
      status: RideRequestStatus.pending,
      estimatedPrice: 10.50,
    );

    await tester.pumpWidget(
      MaterialApp(home: RideConfirmationScreen(request: request)),
    );

    expect(find.text(AppTranslations.cancelRide), findsOneWidget);
  });

  testWidgets('RideConfirmationScreen hides cancel button after ride starts', (
    WidgetTester tester,
  ) async {
    final request = RideRequestData(
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 1,
      paymentMethod: RidePaymentMethod.cash,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 1, 1, 10, 0),
      status: RideRequestStatus.inProgress,
      estimatedPrice: 10.50,
    );

    await tester.pumpWidget(
      MaterialApp(home: RideConfirmationScreen(request: request)),
    );

    expect(find.text(AppTranslations.cancelRide), findsNothing);
  });
  testWidgets(
    'RideConfirmationScreen cancels ride when cancel button is pressed',
    (WidgetTester tester) async {
      final service = CancelTestRideRequestService();

      final request = RideRequestData(
        pickup: 'Pickup',
        destination: 'Destination',
        passengers: 1,
        paymentMethod: RidePaymentMethod.cash,
        rideType: RideType.city,
        requestedAt: DateTime(2026, 1, 1, 10, 0),
        status: RideRequestStatus.pending,
        estimatedPrice: 10.50,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RideConfirmationScreen(
            request: request,
            rideRequestService: service,
          ),
        ),
      );

      final cancelButton = find.widgetWithText(
        OutlinedButton,
        AppTranslations.cancelRide,
      );

      expect(cancelButton, findsOneWidget);

      await tester.ensureVisible(cancelButton);
      await tester.pumpAndSettle();

      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(service.cancelCalled, isTrue);

      expect(
        find.text(AppTranslations.rideCancelled),
        findsWidgets,
      );

      expect(
        find.text(AppTranslations.cancelRide),
        findsNothing,
      );
    },
  );
}
