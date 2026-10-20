import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_app/localization/translations.dart';
import 'package:taxi_app/localization/app_language.dart';
import 'package:taxi_app/models/ride.dart';
import 'package:taxi_app/models/ride_request_data.dart';
import 'package:taxi_app/models/ride_request_status.dart';
import 'package:taxi_app/screens/ride_confirmation_screen.dart';
import 'support/mock_ride_request_service.dart';
import 'package:taxi_app/models/driver_info.dart';
import 'package:taxi_app/services/ride_request_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxi_app/services/active_ride_store.dart';
import 'package:taxi_app/services/ride_bonus_decision_service.dart';

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

    return request.copyWith(status: RideRequestStatus.cancelled);
  }

  @override
  Stream<RideRequestData> watchRequestStatus(RideRequestData request) {
    return const Stream<RideRequestData>.empty();
  }
}

class FailingCancelRideRequestService implements RideRequestService {
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
    throw Exception('Cancel failed');
  }

  @override
  Stream<RideRequestData> watchRequestStatus(RideRequestData request) {
    return const Stream<RideRequestData>.empty();
  }
}

class StatusStreamRideRequestService implements RideRequestService {
  final RideRequestData updatedRequest;

  StatusStreamRideRequestService(this.updatedRequest);

  @override
  Future<RideRequestData> submitRequest(RideRequestData request) async {
    return request;
  }

  @override
  Future<RideRequestData> getRequestStatus(RideRequestData request) async {
    return updatedRequest;
  }

  @override
  Future<RideRequestData> cancelRequest(RideRequestData request) async {
    return request;
  }

  @override
  Stream<RideRequestData> watchRequestStatus(RideRequestData request) {
    return Stream<RideRequestData>.value(updatedRequest);
  }
}

class ControlledRideRequestService
    implements RideRequestService, RideBonusDecisionService {
  ControlledRideRequestService({this.bonusResult});

  final Completer<RideRequestData>? bonusResult;
  int watchCallCount = 0;
  int cancelCallCount = 0;
  int acceptBonusCallCount = 0;
  int declineBonusCallCount = 0;
  bool statusStreamHasNoListeners = false;

  late final StreamController<RideRequestData> _updates =
      StreamController<RideRequestData>.broadcast(
        onCancel: () {
          statusStreamHasNoListeners = true;
        },
      );

  void publish(RideRequestData request) {
    _updates.add(request);
  }

  void publishError(Object error) {
    _updates.addError(error);
  }

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
    cancelCallCount++;
    return request.copyWith(status: RideRequestStatus.cancelled);
  }

  @override
  Stream<RideRequestData> watchRequestStatus(RideRequestData request) {
    watchCallCount++;

    return Stream<RideRequestData>.multi((sink) {
      sink.add(request);
      final subscription = _updates.stream.listen(
        sink.add,
        onError: (Object error, StackTrace stackTrace) {
          sink.addError(error, stackTrace);
        },
        onDone: sink.close,
      );
      sink.onCancel = subscription.cancel;
    });
  }

  @override
  Future<RideRequestData> acceptBonus(RideRequestData request) async {
    acceptBonusCallCount++;
    final result = bonusResult;
    if (result != null) {
      return result.future;
    }

    return request.copyWith(
      bonusDecision: RideBonusDecision.accepted,
      driverBonusMinor: 500,
    );
  }

  @override
  Future<RideRequestData> declineBonus(RideRequestData request) async {
    declineBonusCallCount++;
    return request.copyWith(bonusDecision: RideBonusDecision.declined);
  }
}

void useWideTestSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('RideConfirmationScreen displays estimated price in euros', (
    WidgetTester tester,
  ) async {
    final request = RideRequestData(
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 1,
      paymentMethod: RidePaymentMethod.cash,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 1, 1, 10),
      status: RideRequestStatus.pending,
      estimatedPrice: 10.50,
    );

    await tester.pumpWidget(
      MaterialApp(home: RideConfirmationScreen(request: request)),
    );

    expect(find.textContaining('10.50 €'), findsOneWidget);
    expect(find.textContaining('лв.'), findsNothing);
  });

  testWidgets('completed ride displays meter fare separately from bonus', (
    WidgetTester tester,
  ) async {
    AppTranslations.currentLanguage = AppLanguage.bulgarian;
    addTearDown(() {
      AppTranslations.currentLanguage = AppLanguage.bulgarian;
    });

    final request = RideRequestData(
      requestId: 'ride-final-fare-001',
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 1,
      paymentMethod: RidePaymentMethod.cash,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 1, 1, 10),
      status: RideRequestStatus.completed,
      estimatedPrice: 4.95,
      meterFareMinor: 520,
      bonusDecision: RideBonusDecision.accepted,
      driverBonusMinor: 500,
    );

    await tester.pumpWidget(
      MaterialApp(home: RideConfirmationScreen(request: request)),
    );

    expect(find.text('Крайна цена: 5,20 €'), findsOneWidget);
    expect(find.textContaining('4.95 €'), findsNothing);
    expect(find.text(AppTranslations.bonusAcceptedNotice), findsOneWidget);
  });

  testWidgets(
    'completed ride reports missing or zero meter fare as unavailable',
    (WidgetTester tester) async {
      for (final fare in <int?>[null, 0]) {
        final request = RideRequestData(
          pickup: 'Pickup',
          destination: 'Destination',
          passengers: 1,
          paymentMethod: RidePaymentMethod.cash,
          rideType: RideType.city,
          requestedAt: DateTime(2026, 1, 1, 10),
          status: RideRequestStatus.completed,
          estimatedPrice: 4.95,
          meterFareMinor: fare,
        );

        await tester.pumpWidget(
          MaterialApp(home: RideConfirmationScreen(request: request)),
        );

        expect(find.text('Крайна цена: Не е налична'), findsOneWidget);
        expect(find.textContaining('4.95 €'), findsNothing);
      }
    },
  );

  testWidgets('completed meter fare uses the English label and format', (
    WidgetTester tester,
  ) async {
    AppTranslations.currentLanguage = AppLanguage.english;
    addTearDown(() {
      AppTranslations.currentLanguage = AppLanguage.bulgarian;
    });

    final request = RideRequestData(
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 1,
      paymentMethod: RidePaymentMethod.cash,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 1, 1, 10),
      status: RideRequestStatus.completed,
      estimatedPrice: 4.95,
      meterFareMinor: 520,
    );

    await tester.pumpWidget(
      MaterialApp(home: RideConfirmationScreen(request: request)),
    );

    expect(find.text('Final price: 5.20 €'), findsOneWidget);
  });

  testWidgets('persists active ride status update', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final preferences = await SharedPreferences.getInstance();
    final store = ActiveRideStore(preferences);

    final request = RideRequestData(
      requestId: 'ride-persistence-001',
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 1,
      paymentMethod: RidePaymentMethod.cash,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 10, 2, 16),
      status: RideRequestStatus.waitingForVehicle,
      estimatedPrice: 10.50,
    );

    final acceptedRequest = request.copyWith(
      status: RideRequestStatus.accepted,
      assignedDriverId: 'driver-001',
      assignedVehicleId: 'vehicle-001',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RideConfirmationScreen(
          request: request,
          rideRequestService: StatusStreamRideRequestService(acceptedRequest),
          activeRideStore: store,
        ),
      ),
    );

    await tester.pumpAndSettle();

    final storedRequest = store.load();

    expect(storedRequest, isNotNull);
    expect(storedRequest!.requestId, 'ride-persistence-001');
    expect(storedRequest.status, RideRequestStatus.accepted);
    expect(storedRequest.assignedDriverId, 'driver-001');
    expect(storedRequest.assignedVehicleId, 'vehicle-001');
  });

  testWidgets('clears persisted ride when status becomes completed', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final preferences = await SharedPreferences.getInstance();
    final store = ActiveRideStore(preferences);

    final request = RideRequestData(
      requestId: 'ride-persistence-002',
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 1,
      paymentMethod: RidePaymentMethod.cash,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 10, 2, 16),
      status: RideRequestStatus.inProgress,
      estimatedPrice: 10.50,
    );

    await store.save(request);

    final completedRequest = request.copyWith(
      status: RideRequestStatus.completed,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RideConfirmationScreen(
          request: request,
          rideRequestService: StatusStreamRideRequestService(completedRequest),
          activeRideStore: store,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(store.load(), isNull);
  });

  testWidgets(
    'keeps the last stored status during a retry gap and applies recovery on one subscription',
    (WidgetTester tester) async {
      useWideTestSurface(tester);
      SharedPreferences.setMockInitialValues({});

      final preferences = await SharedPreferences.getInstance();
      final store = ActiveRideStore(preferences);
      final request = RideRequestData(
        requestId: 'ride-recovery-001',
        pickup: 'Pickup',
        destination: 'Destination',
        passengers: 1,
        paymentMethod: RidePaymentMethod.cash,
        rideType: RideType.city,
        requestedAt: DateTime(2026, 10, 2, 16),
        status: RideRequestStatus.waitingForVehicle,
      );
      await store.save(request);

      final service = ControlledRideRequestService();
      await tester.pumpWidget(
        MaterialApp(
          home: RideConfirmationScreen(
            request: request,
            rideRequestService: service,
            activeRideStore: store,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(service.watchCallCount, 1);
      expect(store.load()?.status, RideRequestStatus.waitingForVehicle);

      // A resilient backend stream emits no error while an individual GET is
      // being retried. The saved status remains until the recovery response.
      await tester.pump();
      expect(store.load()?.status, RideRequestStatus.waitingForVehicle);

      service.publish(
        request.copyWith(
          status: RideRequestStatus.accepted,
          assignedDriverId: 'driver-001',
          assignedVehicleId: 'vehicle-001',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppTranslations.acceptedRideTitle), findsOneWidget);
      expect(store.load()?.status, RideRequestStatus.accepted);
      expect(store.load()?.assignedDriverId, 'driver-001');
      expect(service.watchCallCount, 1);
    },
  );

  testWidgets('surfaces a permanent status polling error to the customer', (
    WidgetTester tester,
  ) async {
    useWideTestSurface(tester);
    AppTranslations.currentLanguage = AppLanguage.bulgarian;
    addTearDown(() {
      AppTranslations.currentLanguage = AppLanguage.bulgarian;
    });
    final request = RideRequestData(
      requestId: 'ride-status-error-001',
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 1,
      paymentMethod: RidePaymentMethod.cash,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 10, 2, 16),
      status: RideRequestStatus.pending,
    );
    final service = ControlledRideRequestService();

    await tester.pumpWidget(
      MaterialApp(
        home: RideConfirmationScreen(
          request: request,
          rideRequestService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    service.publishError(StateError('Backend rejected the status request.'));
    await tester.pumpAndSettle();

    expect(
      find.text('Неуспешно обновяване на статуса на поръчката.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'bonus decision remains authoritative while status updates race',
    (WidgetTester tester) async {
      useWideTestSurface(tester);
      final bonusResult = Completer<RideRequestData>();
      final request = RideRequestData(
        requestId: 'ride-bonus-poll-001',
        pickup: 'Pickup',
        destination: 'Destination',
        passengers: 1,
        paymentMethod: RidePaymentMethod.cash,
        rideType: RideType.city,
        requestedAt: DateTime(2026, 10, 2, 16),
        status: RideRequestStatus.pending,
        bonusDecision: RideBonusDecision.awaitingCustomer,
      );
      final acceptedRequest = request.copyWith(
        bonusDecision: RideBonusDecision.accepted,
        driverBonusMinor: 500,
      );
      final service = ControlledRideRequestService(bonusResult: bonusResult);

      await tester.pumpWidget(
        MaterialApp(
          home: RideConfirmationScreen(
            request: request,
            rideRequestService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final acceptBonusButton = find.text(AppTranslations.acceptFiveEuroBonus);
      await tester.ensureVisible(acceptBonusButton);
      await tester.tap(acceptBonusButton);
      await tester.pump();
      service.publish(request);
      await tester.pump();

      bonusResult.complete(acceptedRequest);
      await tester.pumpAndSettle();
      service.publish(request);
      await tester.pumpAndSettle();

      expect(service.watchCallCount, 1);
      expect(service.acceptBonusCallCount, 1);
      expect(service.declineBonusCallCount, 0);
      expect(find.text(AppTranslations.bonusAcceptedNotice), findsOneWidget);
      expect(find.text(AppTranslations.acceptFiveEuroBonus), findsNothing);
    },
  );

  testWidgets('successful cancellation stops status observation', (
    WidgetTester tester,
  ) async {
    useWideTestSurface(tester);
    SharedPreferences.setMockInitialValues({});

    final preferences = await SharedPreferences.getInstance();
    final store = ActiveRideStore(preferences);
    final request = RideRequestData(
      requestId: 'ride-cancel-poll-001',
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 1,
      paymentMethod: RidePaymentMethod.cash,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 10, 2, 16),
      status: RideRequestStatus.pending,
    );
    await store.save(request);
    final service = ControlledRideRequestService();

    await tester.pumpWidget(
      MaterialApp(
        home: RideConfirmationScreen(
          request: request,
          rideRequestService: service,
          activeRideStore: store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cancelButton = find.widgetWithText(
      OutlinedButton,
      AppTranslations.cancelRide,
    );
    await tester.ensureVisible(cancelButton);
    await tester.tap(cancelButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppTranslations.cancelRide).last);
    await tester.pumpAndSettle();

    expect(service.cancelCallCount, 1);
    expect(service.statusStreamHasNoListeners, isTrue);
    expect(find.text(AppTranslations.rideCancelled), findsWidgets);
    expect(store.load(), isNull);
  });

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

    expect(find.text(AppTranslations.acceptedRideTitle), findsOneWidget);
    expect(find.text(AppTranslations.acceptedRideMessage), findsOneWidget);
  });
  testWidgets('RideConfirmationScreen shows driver info when accepted', (
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
      driverInfo: const DriverInfo(
        name: 'Ivan Ivanov',
        vehicle: 'Toyota Prius',
        licensePlate: 'CB1234AB',
        etaMinutes: 5,
        phoneNumber: '+359888123456',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: RideConfirmationScreen(request: request)),
    );

    expect(find.text('Ivan Ivanov'), findsOneWidget);
    expect(find.text('Toyota Prius'), findsOneWidget);
    expect(find.text('CB1234AB'), findsOneWidget);
    expect(find.text(AppTranslations.callDriver), findsOneWidget);
    expect(
      find.text('${AppTranslations.arrivalTime}: 5 ${AppTranslations.minutes}'),
      findsOneWidget,
    );
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
    expect(find.text(AppTranslations.driverArrivingMessage), findsNothing);
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

    expect(find.text(AppTranslations.rideInProgress), findsWidgets);
    expect(find.text(AppTranslations.callDriver), findsNothing);
    expect(find.text('Test Driver'), findsOneWidget);
    expect(find.text('CB 1234 AB'), findsOneWidget);
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
    expect(find.text(AppTranslations.rideCompletedMessage), findsOneWidget);
    AppTranslations.currentLanguage = AppLanguage.english;

    await tester.pumpWidget(
      MaterialApp(home: RideConfirmationScreen(request: request)),
    );

    expect(find.text('Thank you for using City6.'), findsOneWidget);

    AppTranslations.currentLanguage = AppLanguage.bulgarian;
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
    expect(find.text(AppTranslations.rideCancelledMessage), findsOneWidget);
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
    await tester.ensureVisible(find.text(AppTranslations.callDriver));

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
    await tester.ensureVisible(find.text(AppTranslations.callDriver));

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
    await tester.ensureVisible(find.text(AppTranslations.callDriver));

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
    expect(find.text(AppTranslations.rideInProgressMessage), findsNothing);
  });
  testWidgets('RideConfirmationScreen shows cancellation confirmation dialog', (
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
          rideRequestService: CancelTestRideRequestService(),
        ),
      ),
    );

    final cancelButton = find.widgetWithText(
      OutlinedButton,
      AppTranslations.cancelRide,
    );

    expect(cancelButton, findsOneWidget);

    final button = tester.widget<OutlinedButton>(cancelButton);

    expect(button.onPressed, isNotNull);

    button.onPressed!.call();
    await tester.pumpAndSettle();

    expect(
      find.text(AppTranslations.cancelRideConfirmationTitle),
      findsOneWidget,
    );

    expect(
      find.text(AppTranslations.cancelRideConfirmationMessage),
      findsOneWidget,
    );

    expect(find.text(AppTranslations.keepRide), findsOneWidget);
  });
  testWidgets(
    'RideConfirmationScreen shows processing state when cancellation starts',
    (WidgetTester tester) async {
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
            rideRequestService: CancelTestRideRequestService(),
          ),
        ),
      );

      final cancelButton = find.widgetWithText(
        OutlinedButton,
        AppTranslations.cancelRide,
      );

      expect(cancelButton, findsOneWidget);

      final button = tester.widget<OutlinedButton>(cancelButton);

      button.onPressed!.call();

      await tester.pump();

      expect(find.text(AppTranslations.processing), findsOneWidget);
    },
  );
  testWidgets(
    'RideConfirmationScreen keeps ride when cancellation is dismissed',
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

      final button = tester.widget<OutlinedButton>(cancelButton);

      button.onPressed!.call();
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppTranslations.keepRide));

      await tester.pumpAndSettle();

      expect(service.cancelCalled, isFalse);

      expect(find.text(AppTranslations.rideRequestSent), findsOneWidget);
    },
  );
  testWidgets(
    'RideConfirmationScreen cancels ride when cancellation is confirmed',
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

      final button = tester.widget<OutlinedButton>(cancelButton);

      button.onPressed!.call();
      await tester.pumpAndSettle();

      expect(
        find.text(AppTranslations.cancelRideConfirmationTitle),
        findsOneWidget,
      );

      await tester.tap(find.text(AppTranslations.cancelRide).last);

      await tester.pumpAndSettle();

      expect(service.cancelCalled, isTrue);

      expect(find.text(AppTranslations.rideCancelled), findsWidgets);

      expect(find.text(AppTranslations.cancelRide), findsNothing);
    },
  );
  testWidgets('RideConfirmationScreen hides cancel button after cancellation', (
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
          rideRequestService: CancelTestRideRequestService(),
        ),
      ),
    );

    final cancelButton = find.widgetWithText(
      OutlinedButton,
      AppTranslations.cancelRide,
    );

    expect(cancelButton, findsOneWidget);

    await tester.tap(cancelButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppTranslations.cancelRide).last);
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(OutlinedButton, AppTranslations.cancelRide),
      findsNothing,
    );

    expect(find.text(AppTranslations.rideCancelled), findsWidgets);
  });
  testWidgets('RideConfirmationScreen shows error when cancellation fails', (
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
          rideRequestService: FailingCancelRideRequestService(),
        ),
      ),
    );

    final cancelButton = find.widgetWithText(
      OutlinedButton,
      AppTranslations.cancelRide,
    );

    final button = tester.widget<OutlinedButton>(cancelButton);

    button.onPressed!.call();
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppTranslations.cancelRide).last);

    await tester.pumpAndSettle();

    expect(find.text(AppTranslations.cancelRideFailed), findsOneWidget);

    expect(find.text(AppTranslations.rideCancelled), findsNothing);

    expect(find.text(AppTranslations.cancelRide), findsOneWidget);
  });
  testWidgets('RideConfirmationScreen shows cancelled message in English', (
    WidgetTester tester,
  ) async {
    AppTranslations.currentLanguage = AppLanguage.english;

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

    expect(
      find.text('The ride request was cancelled successfully.'),
      findsOneWidget,
    );

    AppTranslations.currentLanguage = AppLanguage.bulgarian;
  });
  testWidgets('completed ride OK button returns to first route', (
    WidgetTester tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    final request = RideRequestData(
      pickup: 'Pickup',
      destination: 'Destination',
      passengers: 1,
      paymentMethod: RidePaymentMethod.cash,
      rideType: RideType.city,
      requestedAt: DateTime(2026, 1, 1, 10),
      status: RideRequestStatus.completed,
      estimatedPrice: 10.50,
    );

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('Intro screen marker')),
      ),
    );

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Order flow marker')),
      ),
    );

    await tester.pumpAndSettle();

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => RideConfirmationScreen(request: request),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(AppTranslations.okButton), findsOneWidget);

    await tester.ensureVisible(find.text(AppTranslations.okButton));

    await tester.tap(find.text(AppTranslations.okButton));

    await tester.pumpAndSettle();

    expect(find.text('Intro screen marker'), findsOneWidget);

    expect(find.text('Order flow marker'), findsNothing);

    expect(find.byType(RideConfirmationScreen), findsNothing);
  });
}
