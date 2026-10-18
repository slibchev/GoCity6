import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_app/localization/app_language.dart';
import 'package:taxi_app/localization/translations.dart';
import 'package:taxi_app/models/ride.dart';
import 'package:taxi_app/models/ride_request_data.dart';
import 'package:taxi_app/models/ride_request_status.dart';
import 'package:taxi_app/screens/ride_confirmation_screen.dart';
import 'package:taxi_app/services/ride_bonus_decision_service.dart';
import 'package:taxi_app/services/ride_request_service.dart';

class TestBonusService implements RideRequestService, RideBonusDecisionService {
  TestBonusService(this.current);

  RideRequestData current;
  int acceptCalls = 0;
  int declineCalls = 0;

  @override
  Future<RideRequestData> acceptBonus(RideRequestData request) async {
    acceptCalls++;
    current = request.copyWith(
      bonusDecision: RideBonusDecision.accepted,
      driverBonusMinor: 500,
    );
    return current;
  }

  @override
  Future<RideRequestData> declineBonus(RideRequestData request) async {
    declineCalls++;
    current = request.copyWith(
      status: RideRequestStatus.waitingForVehicle,
      bonusDecision: RideBonusDecision.declined,
      driverBonusMinor: 0,
    );
    return current;
  }

  @override
  Future<RideRequestData> submitRequest(RideRequestData request) async {
    return current;
  }

  @override
  Future<RideRequestData> getRequestStatus(RideRequestData request) async {
    return current;
  }

  @override
  Future<RideRequestData> cancelRequest(RideRequestData request) async {
    return current;
  }

  @override
  Stream<RideRequestData> watchRequestStatus(RideRequestData request) async* {
    yield current;
  }
}

RideRequestData testRide({
  RideBonusDecision decision = RideBonusDecision.awaitingCustomer,
  RideRequestStatus status = RideRequestStatus.pending,
}) {
  return RideRequestData(
    requestId: 'test-bonus-ride',
    pickup: 'Sofia Center',
    destination: 'Sofia Airport',
    passengers: 2,
    paymentMethod: RidePaymentMethod.cash,
    rideType: RideType.city,
    requestedAt: DateTime(2026, 10, 18, 20),
    status: status,
    bonusDecision: decision,
    estimatedPrice: 8.50,
  );
}

void main() {
  setUp(() {
    AppTranslations.currentLanguage = AppLanguage.bulgarian;
  });

  testWidgets('bonus buttons appear only when customer decision is needed', (
    tester,
  ) async {
    final request = testRide();
    final service = TestBonusService(request);

    await tester.pumpWidget(
      MaterialApp(
        home: RideConfirmationScreen(
          request: request,
          rideRequestService: service,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(AppTranslations.acceptFiveEuroBonus), findsOneWidget);
    expect(find.text(AppTranslations.declineFiveEuroBonus), findsOneWidget);
    expect(find.text(AppTranslations.bonusAwaitingDecision), findsOneWidget);
  });

  testWidgets('accepting bonus starts bonus dispatch', (tester) async {
    final request = testRide();
    final service = TestBonusService(request);

    await tester.pumpWidget(
      MaterialApp(
        home: RideConfirmationScreen(
          request: request,
          rideRequestService: service,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(AppTranslations.acceptFiveEuroBonus));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppTranslations.acceptFiveEuroBonus));
    await tester.pumpAndSettle();

    expect(service.acceptCalls, 1);
    expect(service.declineCalls, 0);
    expect(service.current.driverBonusMinor, 500);
    expect(find.text(AppTranslations.bonusAcceptedNotice), findsOneWidget);
    expect(find.text(AppTranslations.acceptFiveEuroBonus), findsNothing);
  });

  testWidgets('declining bonus keeps the request without bonus', (
    tester,
  ) async {
    final request = testRide();
    final service = TestBonusService(request);

    await tester.pumpWidget(
      MaterialApp(
        home: RideConfirmationScreen(
          request: request,
          rideRequestService: service,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(AppTranslations.declineFiveEuroBonus));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppTranslations.declineFiveEuroBonus));
    await tester.pumpAndSettle();

    expect(service.acceptCalls, 0);
    expect(service.declineCalls, 1);
    expect(service.current.status, RideRequestStatus.waitingForVehicle);
    expect(service.current.driverBonusMinor, 0);
    expect(find.text(AppTranslations.acceptFiveEuroBonus), findsNothing);
  });

  testWidgets('normal pending request does not offer bonus', (tester) async {
    final request = testRide(decision: RideBonusDecision.notOffered);
    final service = TestBonusService(request);

    await tester.pumpWidget(
      MaterialApp(
        home: RideConfirmationScreen(
          request: request,
          rideRequestService: service,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(AppTranslations.acceptFiveEuroBonus), findsNothing);
    expect(find.text(AppTranslations.declineFiveEuroBonus), findsNothing);
  });
}
