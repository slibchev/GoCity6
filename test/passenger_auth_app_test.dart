import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxi_app/main.dart';
import 'package:taxi_app/models/ride.dart';
import 'package:taxi_app/models/ride_request_data.dart';
import 'package:taxi_app/models/ride_request_status.dart';
import 'package:taxi_app/screens/city6_intro_screen.dart';
import 'package:taxi_app/screens/passenger_login_screen.dart';
import 'package:taxi_app/screens/sms_verification_screen.dart';
import 'package:taxi_app/services/active_ride_store.dart';
import 'package:taxi_app/services/passenger_auth_service.dart';
import 'package:taxi_app/services/ride_request_service.dart';

class AppTestTokenStorage implements PassengerTokenStorage {
  String? token;

  AppTestTokenStorage([this.token]);

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String token) async {
    this.token = token;
  }

  @override
  Future<void> deleteToken() async {
    token = null;
  }
}

class NoOpRideRequestService implements RideRequestService {
  @override
  Future<RideRequestData> submitRequest(RideRequestData request) async =>
      request;

  @override
  Future<RideRequestData> getRequestStatus(RideRequestData request) async =>
      request;

  @override
  Future<RideRequestData> cancelRequest(RideRequestData request) async =>
      request.copyWith(status: RideRequestStatus.cancelled);

  @override
  Stream<RideRequestData> watchRequestStatus(RideRequestData request) =>
      const Stream<RideRequestData>.empty();
}

RideRequestData storedRide() => RideRequestData(
  requestId: 'ride-for-passenger-101',
  pickup: 'Pickup',
  destination: 'Destination',
  passengers: 2,
  paymentMethod: RidePaymentMethod.cash,
  rideType: RideType.city,
  requestedAt: DateTime(2026, 10, 31, 12),
  status: RideRequestStatus.accepted,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('legacy isRegistered flag does not authenticate the passenger', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'isRegistered': true});
    final preferences = await SharedPreferences.getInstance();
    final authService = PassengerAuthService(
      baseUrl: 'https://unit.test',
      client: MockClient((_) async => fail('No saved token should call API.')),
      tokenStorage: AppTestTokenStorage(),
    );

    await tester.pumpWidget(
      TaxiApp(
        authService: authService,
        preferences: preferences,
        rideRequestService: NoOpRideRequestService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PassengerLoginScreen), findsOneWidget);
    expect(find.byType(City6IntroScreen), findsNothing);
  });

  testWidgets('restored profile can logout without deleting its active ride', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final store = ActiveRideStore(preferences, passengerId: '101');
    await store.save(storedRide());
    final tokenStorage = AppTestTokenStorage('synthetic-session-token');
    final authService = PassengerAuthService(
      baseUrl: 'https://unit.test',
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/passenger/session');
        expect(
          request.headers['authorization'],
          'Bearer synthetic-session-token',
        );
        return http.Response(
          jsonEncode({
            'authenticated': true,
            'passenger': {'id': 101, 'username': 'city6_passenger_01'},
          }),
          200,
        );
      }),
      tokenStorage: tokenStorage,
    );

    await tester.pumpWidget(
      TaxiApp(
        authService: authService,
        preferences: preferences,
        rideRequestService: NoOpRideRequestService(),
        skipIntroAnimation: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(City6IntroScreen), findsOneWidget);
    expect(find.text('Имате направена поръчка'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Изход').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Изход').last);
    await tester.pumpAndSettle();

    expect(find.byType(PassengerLoginScreen), findsOneWidget);
    expect(tokenStorage.token, isNull);
    expect(
      ActiveRideStore(preferences, passengerId: '101').load()?.requestId,
      'ride-for-passenger-101',
    );
  });

  testWidgets(
    'legacy demo SMS code cannot establish an authenticated session',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SmsVerificationScreen(phoneNumber: '+359 88 000 0000'),
        ),
      );
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('ПОТВЪРДИ'));
      await tester.pump();

      expect(find.byType(SmsVerificationScreen), findsOneWidget);
      expect(find.text('Тестов код: 123456'), findsNothing);
    },
  );
}
