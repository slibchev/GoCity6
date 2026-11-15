import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxi_app/localization/app_language.dart';
import 'package:taxi_app/localization/translations.dart';
import 'package:taxi_app/main.dart';
import 'package:taxi_app/models/ride.dart';
import 'package:taxi_app/models/ride_request_data.dart';
import 'package:taxi_app/models/ride_request_status.dart';
import 'package:taxi_app/screens/city6_intro_screen.dart';
import 'package:taxi_app/screens/home_screen.dart';
import 'package:taxi_app/screens/language_screen.dart';
import 'package:taxi_app/screens/passenger_login_screen.dart';
import 'package:taxi_app/screens/ride_confirmation_screen.dart';
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
    AppTranslations.currentLanguage = AppLanguage.bulgarian;
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

    expect(find.byType(LanguageScreen), findsOneWidget);
    expect(find.byType(PassengerLoginScreen), findsNothing);
    expect(find.byType(City6IntroScreen), findsNothing);

    await tester.tap(find.text('Български'));
    await tester.pumpAndSettle();

    expect(find.byType(LanguageScreen), findsNothing);
    expect(find.byType(PassengerLoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(preferences.getString('language'), 'bulgarian');
  });

  testWidgets(
    'first launch saves English and skips language choice on restart',
    (tester) async {
      final preferences = await SharedPreferences.getInstance();
      final authService = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient((_) async => fail('No token should call the API.')),
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

      expect(find.byType(LanguageScreen), findsOneWidget);
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(preferences.getString('language'), 'english');
      expect(AppTranslations.currentLanguage, AppLanguage.english);
      expect(find.byType(PassengerLoginScreen), findsOneWidget);
      expect(find.byType(City6IntroScreen), findsNothing);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.text('Sign in to City6'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        TaxiApp(
          authService: authService,
          preferences: preferences,
          rideRequestService: NoOpRideRequestService(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LanguageScreen), findsNothing);
      expect(find.byType(PassengerLoginScreen), findsOneWidget);
      expect(find.text('Sign in to City6'), findsOneWidget);
    },
  );

  testWidgets('saved language is used without showing the picker', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'language': 'english'});
    final preferences = await SharedPreferences.getInstance();
    final authService = PassengerAuthService(
      baseUrl: 'https://unit.test',
      client: MockClient((_) async => fail('No token should call the API.')),
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

    expect(find.byType(LanguageScreen), findsNothing);
    expect(find.byType(PassengerLoginScreen), findsOneWidget);
    expect(find.text('Sign in to City6'), findsOneWidget);
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
    expect(find.byType(LanguageScreen), findsNothing);
    expect(find.text('Имате направена поръчка'), findsOneWidget);
    expect(preferences.getString('language'), 'bulgarian');

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

  testWidgets('temporary session check error does not open language picker', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final tokenStorage = AppTestTokenStorage('stored-session-token');
    final authService = PassengerAuthService(
      baseUrl: 'https://unit.test',
      client: MockClient((_) async => throw http.ClientException('offline')),
      tokenStorage: tokenStorage,
    );

    await tester.pumpWidget(
      TaxiApp(
        authService: authService,
        preferences: preferences,
        rideRequestService: NoOpRideRequestService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LanguageScreen), findsNothing);
    expect(find.byType(PassengerLoginScreen), findsOneWidget);
    expect(
      find.text(AppTranslations.passengerSessionCheckError),
      findsOneWidget,
    );
    expect(tokenStorage.token, 'stored-session-token');
  });

  testWidgets('disposing during session restore does not update disposed app', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final tokenStorage = AppTestTokenStorage('stored-session-token');
    final response = Completer<http.Response>();
    final authService = PassengerAuthService(
      baseUrl: 'https://unit.test',
      client: MockClient((_) => response.future),
      tokenStorage: tokenStorage,
    );

    await tester.pumpWidget(
      TaxiApp(
        authService: authService,
        preferences: preferences,
        rideRequestService: NoOpRideRequestService(),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    response.complete(
      http.Response(
        jsonEncode({
          'authenticated': true,
          'passenger': {'id': 101, 'username': 'city6_passenger_01'},
        }),
        200,
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(tokenStorage.token, 'stored-session-token');
  });

  testWidgets('displayed and saved language remain synchronized', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final authService = PassengerAuthService(
      baseUrl: 'https://unit.test',
      client: MockClient((_) async => fail('No token should call the API.')),
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
    await tester.tap(find.text('Български'));
    await tester.pumpAndSettle();

    expect(find.text('Вход в City6'), findsOneWidget);
    expect(preferences.getString('language'), 'bulgarian');
    expect(AppTranslations.currentLanguage, AppLanguage.bulgarian);

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    expect(find.text('Sign in to City6'), findsOneWidget);
    expect(preferences.getString('language'), 'english');
    expect(AppTranslations.currentLanguage, AppLanguage.english);

    await tester.tap(find.text('БГ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Български').last);
    await tester.pumpAndSettle();

    expect(find.text('Вход в City6'), findsOneWidget);
    expect(preferences.getString('language'), 'bulgarian');
    expect(AppTranslations.currentLanguage, AppLanguage.bulgarian);
  });

  testWidgets('language and login controls remain usable on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final preferences = await SharedPreferences.getInstance();
    final authService = PassengerAuthService(
      baseUrl: 'https://unit.test',
      client: MockClient((_) async => fail('No token should call the API.')),
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

    expect(find.text('English'), findsOneWidget);
    expect(find.text('Български'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Български'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Вход в City6'), findsOneWidget);
    expect(find.text('ВХОД'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'language can change during an active ride without logout or loss',
    (tester) async {
      final preferences = await SharedPreferences.getInstance();
      final store = ActiveRideStore(preferences, passengerId: '101');
      await store.save(storedRide());
      final tokenStorage = AppTestTokenStorage('synthetic-session-token');
      final authService = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient((request) async {
          expect(request.url.path, '/passenger/session');
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
      await tester.tap(find.text(AppTranslations.returnToActiveRide));
      await tester.pumpAndSettle();

      expect(find.byType(RideConfirmationScreen), findsOneWidget);
      expect(find.text('Поръчката Ви е приета успешно'), findsOneWidget);
      await tester.tap(find.text('EN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(AppTranslations.currentLanguage, AppLanguage.english);
      expect(
        find.text('Your ride request was accepted successfully'),
        findsOneWidget,
      );
      expect(find.byType(PassengerLoginScreen), findsNothing);
      expect(tokenStorage.token, 'synthetic-session-token');
      expect(preferences.getString('language'), 'english');
      expect(store.load()?.requestId, 'ride-for-passenger-101');
    },
  );

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
