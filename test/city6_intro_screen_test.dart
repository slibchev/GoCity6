import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taxi_app/localization/app_language.dart';
import 'package:taxi_app/localization/translations.dart';
import 'package:taxi_app/models/ride.dart';
import 'package:taxi_app/models/ride_request_data.dart';
import 'package:taxi_app/models/ride_request_status.dart';
import 'package:taxi_app/screens/city6_intro_screen.dart';
import 'package:taxi_app/services/active_ride_store.dart';
import 'package:taxi_app/services/ride_request_service.dart';

class IntroTestRideRequestService implements RideRequestService {
  final RideRequestData? refreshedRequest;

  int getStatusCallCount = 0;

  IntroTestRideRequestService({this.refreshedRequest});

  @override
  Future<RideRequestData> getRequestStatus(RideRequestData request) async {
    getStatusCallCount++;

    return refreshedRequest ?? request;
  }

  @override
  Future<RideRequestData> submitRequest(RideRequestData request) async {
    return request;
  }

  @override
  Future<RideRequestData> cancelRequest(RideRequestData request) async {
    return request.copyWith(status: RideRequestStatus.cancelled);
  }

  @override
  Stream<RideRequestData> watchRequestStatus(RideRequestData request) {
    return const Stream<RideRequestData>.empty();
  }
}

RideRequestData buildIntroTestRide({required RideRequestStatus status}) {
  return RideRequestData(
    requestId: 'intro-ride-001',
    assignedDriverId: status == RideRequestStatus.accepted
        ? 'driver-001'
        : null,
    assignedVehicleId: status == RideRequestStatus.accepted
        ? 'vehicle-001'
        : null,
    pickup: 'Pickup',
    destination: 'Destination',
    passengers: 1,
    paymentMethod: RidePaymentMethod.cash,
    rideType: RideType.city,
    requestedAt: DateTime(2026, 10, 3, 12),
    status: status,
    estimatedPrice: 12.50,
  );
}

Future<void> pumpIntro(
  WidgetTester tester, {
  required ActiveRideStore store,
  required RideRequestService service,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: City6IntroScreen(
        backgroundAsset: 'assets/images/city6_intro_background.png',
        logoAsset: 'assets/images/city6_intro_logo.png',
        activeRideStore: store,
        rideRequestService: service,
        skipIntroAnimation: true,
      ),
    ),
  );

  // Даваме отделни frame-ове на:
  // image precache -> intro animation -> post-animation delay ->
  // backend recovery check -> setState.
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    AppTranslations.currentLanguage = AppLanguage.bulgarian;
  });

  testWidgets('shows standard order button when no stored ride exists', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final preferences = await SharedPreferences.getInstance();
    final store = ActiveRideStore(preferences);
    final service = IntroTestRideRequestService();

    await pumpIntro(tester, store: store, service: service);

    expect(find.text(AppTranslations.orderTaxi), findsOneWidget);

    expect(find.text(AppTranslations.activeRideNotice), findsNothing);

    expect(service.getStatusCallCount, 0);
  });

  testWidgets('shows recovery actions when stored ride is accepted', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final preferences = await SharedPreferences.getInstance();
    final store = ActiveRideStore(preferences);

    final acceptedRide = buildIntroTestRide(status: RideRequestStatus.accepted);

    await store.save(acceptedRide);

    final service = IntroTestRideRequestService(refreshedRequest: acceptedRide);

    await pumpIntro(tester, store: store, service: service);

    expect(find.text(AppTranslations.activeRideNotice), findsOneWidget);

    expect(find.text(AppTranslations.returnToActiveRide), findsOneWidget);

    expect(find.text(AppTranslations.cancelActiveRide), findsOneWidget);

    expect(find.text(AppTranslations.orderTaxi), findsNothing);

    expect(service.getStatusCallCount, 1);
  });

  testWidgets('does not show recovery actions for unaccepted stored ride', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final preferences = await SharedPreferences.getInstance();
    final store = ActiveRideStore(preferences);

    final waitingRide = buildIntroTestRide(
      status: RideRequestStatus.waitingForVehicle,
    );

    await store.save(waitingRide);

    final service = IntroTestRideRequestService(refreshedRequest: waitingRide);

    await pumpIntro(tester, store: store, service: service);

    expect(find.text(AppTranslations.orderTaxi), findsOneWidget);

    expect(find.text(AppTranslations.activeRideNotice), findsNothing);

    expect(find.text(AppTranslations.returnToActiveRide), findsNothing);

    expect(find.text(AppTranslations.cancelActiveRide), findsNothing);

    expect(service.getStatusCallCount, 1);
  });
}
