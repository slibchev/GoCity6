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
import 'package:taxi_app/screens/passenger_phone_auth_screen.dart';
import 'package:taxi_app/screens/ride_confirmation_screen.dart';
import 'package:taxi_app/screens/sms_verification_screen.dart';
import 'package:taxi_app/services/active_ride_store.dart';
import 'package:taxi_app/services/passenger_auth_service.dart';
import 'package:taxi_app/services/ride_request_service.dart';

class AppTestTokenStorage implements PassengerTokenStorage {
  PassengerStoredCredentials? credentials;

  AppTestTokenStorage([String? token]) {
    if (token != null) {
      credentials = PassengerStoredCredentials(accessToken: token);
    }
  }

  @override
  Future<PassengerStoredCredentials?> readCredentials() async => credentials;

  @override
  Future<void> writeCredentials(PassengerStoredCredentials value) async {
    credentials = value;
  }

  @override
  Future<void> deleteCredentials() async {
    credentials = null;
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

Future<void> pumpSmsRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 400));
}

Finder smsCodeField() => find.descendant(
  of: find.byType(PassengerSmsVerificationScreen),
  matching: find.byType(TextField),
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
    expect(find.byType(PassengerPhoneAuthScreen), findsNothing);
    expect(find.byType(City6IntroScreen), findsNothing);

    await tester.tap(find.text('Български'));
    await tester.pumpAndSettle();

    expect(find.byType(LanguageScreen), findsNothing);
    expect(find.byType(PassengerPhoneAuthScreen), findsOneWidget);
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
      expect(find.byType(PassengerPhoneAuthScreen), findsOneWidget);
      expect(find.byType(City6IntroScreen), findsNothing);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.text('Continue with your phone'), findsOneWidget);

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
      expect(find.byType(PassengerPhoneAuthScreen), findsOneWidget);
      expect(find.text('Continue with your phone'), findsOneWidget);
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
    expect(find.byType(PassengerPhoneAuthScreen), findsOneWidget);
    expect(find.text('Continue with your phone'), findsOneWidget);
  });

  testWidgets(
    'public app authenticates by phone and restores that profile ride',
    (tester) async {
      SharedPreferences.setMockInitialValues({'language': 'english'});
      final preferences = await SharedPreferences.getInstance();
      const passengerId = 'phone-profile-uuid-1';
      final profileRideStore = ActiveRideStore(
        preferences,
        passengerId: passengerId,
      );
      await profileRideStore.save(storedRide());
      final requests = <http.Request>[];
      final activityTypes = <String>[];
      final activityAuthorizations = <String?>[];
      final tokenStorage = AppTestTokenStorage();
      final authService = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/passenger/phone-verifications') {
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'challengeId': 'challenge-app',
                  'status': 'accepted',
                  'maskedPhone': '••••21',
                  'expiresInSeconds': 600,
                  'resendAfterSeconds': 60,
                }),
              ),
              202,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          if (request.url.path.endsWith('/verify')) {
            return http.Response(
              jsonEncode({
                'token': 'phone-access-token',
                'tokenType': 'Bearer',
                'expiresInSeconds': 43200,
                'refreshToken': 'phone-refresh-token',
                'passenger': {
                  'id': passengerId,
                  'username': null,
                  'authMethod': 'phone',
                },
              }),
              200,
            );
          }
          if (request.url.path == '/passenger/session/activity') {
            activityAuthorizations.add(request.headers['authorization']);
            activityTypes.add(
              (jsonDecode(request.body) as Map<String, dynamic>)['activityType']
                  as String,
            );
            return http.Response('{"recorded":true,"duplicate":false}', 200);
          }
          return http.Response('{}', 500);
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
      expect(find.byType(PassengerPhoneAuthScreen), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Username'), findsNothing);
      expect(find.text('Password'), findsNothing);

      await tester.enterText(find.byType(TextField), '+14165550121');
      await tester.tap(find.text('SEND CODE'));
      await pumpSmsRoute(tester);
      await tester.enterText(smsCodeField(), '654321');
      await tester.pump();
      await tapVisible(tester, find.widgetWithText(ElevatedButton, 'VERIFY'));
      expect(
        requests.any((request) => request.url.path.endsWith('/verify')),
        isTrue,
      );
      await tester.pumpAndSettle();

      expect(find.byType(PassengerPhoneAuthScreen), findsNothing);
      expect(find.byType(PassengerSmsVerificationScreen), findsNothing);
      expect(find.byType(City6IntroScreen), findsOneWidget);
      expect(find.text('You have an active ride request'), findsOneWidget);
      expect(tokenStorage.credentials?.passengerId, passengerId);
      expect(tokenStorage.credentials?.refreshToken, 'phone-refresh-token');
      expect(
        requests.map((request) => request.url.path),
        containsAll([
          '/passenger/phone-verifications',
          '/passenger/phone-verifications/challenge-app/verify',
          '/passenger/session/activity',
        ]),
      );
      expect(
        requests.any((request) => request.url.path == '/passenger/login'),
        isFalse,
      );
      expect(profileRideStore.load()?.requestId, 'ride-for-passenger-101');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      await tester.tap(find.text('Back to ride'));
      await tester.pumpAndSettle();
      expect(activityTypes.where((type) => type == 'foreground').length, 2);
      expect(activityTypes, contains('interaction'));
      expect(activityAuthorizations, isNotEmpty);
      expect(activityAuthorizations, everyElement('Bearer phone-access-token'));
    },
  );

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
        if (request.url.path == '/passenger/session/activity') {
          return http.Response('{"recorded":true,"duplicate":false}', 200);
        }
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

    expect(find.byType(PassengerPhoneAuthScreen), findsOneWidget);
    expect(tokenStorage.credentials, isNull);
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
    expect(find.byType(PassengerPhoneAuthScreen), findsOneWidget);
    expect(
      find.text(AppTranslations.passengerSessionCheckError),
      findsOneWidget,
    );
    expect(tokenStorage.credentials?.accessToken, 'stored-session-token');
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
    expect(tokenStorage.credentials?.accessToken, 'stored-session-token');
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

    expect(find.text('Продължете с телефона си'), findsOneWidget);
    expect(preferences.getString('language'), 'bulgarian');
    expect(AppTranslations.currentLanguage, AppLanguage.bulgarian);

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    expect(find.text('Continue with your phone'), findsOneWidget);
    expect(preferences.getString('language'), 'english');
    expect(AppTranslations.currentLanguage, AppLanguage.english);

    await tester.tap(find.text('БГ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Български').last);
    await tester.pumpAndSettle();

    expect(find.text('Продължете с телефона си'), findsOneWidget);
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

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Продължете с телефона си'), findsOneWidget);
    expect(find.text('ИЗПРАТИ КОД'), findsOneWidget);
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
          if (request.url.path == '/passenger/session/activity') {
            return http.Response('{"recorded":true,"duplicate":false}', 200);
          }
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
      expect(find.byType(PassengerPhoneAuthScreen), findsNothing);
      expect(tokenStorage.credentials?.accessToken, 'synthetic-session-token');
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
