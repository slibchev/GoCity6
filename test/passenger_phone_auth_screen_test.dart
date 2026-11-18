import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_app/localization/app_language.dart';
import 'package:taxi_app/localization/translations.dart';
import 'package:taxi_app/models/passenger_session.dart';
import 'package:taxi_app/screens/passenger_phone_auth_screen.dart';
import 'package:taxi_app/services/passenger_auth_service.dart';

class PhoneScreenStorage implements PassengerTokenStorage {
  PassengerStoredCredentials? credentials;

  @override
  Future<PassengerStoredCredentials?> readCredentials() async => credentials;

  @override
  Future<void> writeCredentials(PassengerStoredCredentials value) async {
    credentials = value;
  }

  @override
  Future<void> deleteCredentials() async => credentials = null;
}

Map<String, dynamic> smsChallenge({int expires = 600, int resendAfter = 60}) =>
    {
      'challengeId': 'challenge-1',
      'status': 'accepted',
      'maskedPhone': '••••56',
      'expiresInSeconds': expires,
      'resendAfterSeconds': resendAfter,
    };

Map<String, dynamic> verifiedSession() => {
  'token': 'synthetic-access-token',
  'tokenType': 'Bearer',
  'expiresInSeconds': 43200,
  'refreshToken': 'synthetic-refresh-token',
  'passenger': {
    'id': 'stable-passenger-id',
    'username': null,
    'authMethod': 'phone',
  },
};

http.Response utf8JsonResponse(Map<String, dynamic> body, int statusCode) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
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
  setUp(() => AppTranslations.currentLanguage = AppLanguage.bulgarian);

  testWidgets('phone challenge verifies to a phone-only passenger session', (
    tester,
  ) async {
    final storage = PhoneScreenStorage();
    final requests = <http.Request>[];
    final service = PassengerAuthService(
      baseUrl: 'https://unit.test',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/passenger/phone-verifications') {
          return utf8JsonResponse(smsChallenge(), 202);
        }
        if (request.url.path.endsWith('/verify')) {
          return http.Response(jsonEncode(verifiedSession()), 200);
        }
        return http.Response('{}', 500);
      }),
      tokenStorage: storage,
    );
    PassengerSession? authenticated;

    await tester.pumpWidget(
      MaterialApp(
        home: PassengerPhoneAuthScreen(
          authService: service,
          onAuthenticated: (session) async => authenticated = session,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '00359 88 123 4567');
    await tester.tap(find.text('ИЗПРАТИ КОД'));
    await pumpSmsRoute(tester);

    expect(find.byType(PassengerSmsVerificationScreen), findsOneWidget);
    expect(find.textContaining('••••56'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PassengerSmsVerificationScreen),
        matching: find.textContaining('••••56'),
      ),
      findsOneWidget,
    );
    expect(jsonDecode(requests.first.body), {'phoneNumber': '+359881234567'});

    await tester.enterText(smsCodeField(), '654321');
    await tester.pump();
    expect(tester.widget<TextField>(smsCodeField()).controller?.text, '654321');
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'ПОТВЪРДИ'),
          )
          .onPressed,
      isNotNull,
    );
    await tapVisible(tester, find.widgetWithText(ElevatedButton, 'ПОТВЪРДИ'));
    await tester.pumpAndSettle();

    expect(
      requests.map((request) => request.url.path),
      contains('/passenger/phone-verifications/challenge-1/verify'),
    );
    expect(authenticated?.passengerId, 'stable-passenger-id');
    expect(authenticated?.username, isNull);
    expect(storage.credentials?.passengerId, 'stable-passenger-id');
    expect(storage.credentials?.refreshToken, 'synthetic-refresh-token');
    expect(requests.map((request) => request.url.path), [
      '/passenger/phone-verifications',
      '/passenger/phone-verifications/challenge-1/verify',
    ]);
  });

  testWidgets(
    'resend is disabled during backend cooldown and uses its limits',
    (tester) async {
      var resendCalls = 0;
      final service = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient((request) async {
          if (request.url.path == '/passenger/phone-verifications') {
            return utf8JsonResponse(
              smsChallenge(expires: 4, resendAfter: 2),
              202,
            );
          }
          if (request.url.path.endsWith('/resend')) {
            resendCalls++;
            return utf8JsonResponse(
              smsChallenge(expires: 3, resendAfter: 2),
              202,
            );
          }
          return http.Response('{}', 500);
        }),
        tokenStorage: PhoneScreenStorage(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PassengerPhoneAuthScreen(
            authService: service,
            onAuthenticated: (_) async {},
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '+359881234567');
      await tester.tap(find.text('ИЗПРАТИ КОД'));
      await pumpSmsRoute(tester);
      expect(
        find.textContaining('Можете да поискате ново съобщение след 2 секунди'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Изпрати кода отново'),
            )
            .onPressed,
        isNull,
      );

      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
      await tester.pump(const Duration(seconds: 1));
      final resendButton = find.widgetWithText(
        TextButton,
        'Изпрати кода отново',
      );
      await tester.ensureVisible(resendButton);
      await tester.tap(resendButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(resendCalls, 1);
      expect(
        find.text(
          'Ако кодът все още е валиден, съобщението може да съдържа същия код.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'challenge expiry disables verification and offers number correction',
    (tester) async {
      final service = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient((request) async {
          if (request.url.path == '/passenger/phone-verifications') {
            return utf8JsonResponse(
              smsChallenge(expires: 600, resendAfter: 1),
              202,
            );
          }
          if (request.url.path.endsWith('/verify')) {
            return http.Response('{}', 404);
          }
          return http.Response('{}', 500);
        }),
        tokenStorage: PhoneScreenStorage(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PassengerPhoneAuthScreen(
            authService: service,
            onAuthenticated: (_) async {},
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '+359881234567');
      await tester.tap(find.text('ИЗПРАТИ КОД'));
      await pumpSmsRoute(tester);
      await tester.enterText(smsCodeField(), '123456');
      await tester.pump();
      await tapVisible(tester, find.widgetWithText(ElevatedButton, 'ПОТВЪРДИ'));

      expect(
        find.textContaining('Заявката за потвърждение е изтекла.'),
        findsOneWidget,
      );
      expect(find.text('Промени номера'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'ПОТВЪРДИ'),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('double tap sends exactly one phone challenge', (tester) async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    var calls = 0;
    final service = PassengerAuthService(
      baseUrl: 'https://unit.test',
      client: MockClient((_) {
        calls++;
        started.complete();
        return response.future;
      }),
      tokenStorage: PhoneScreenStorage(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PassengerPhoneAuthScreen(
          authService: service,
          onAuthenticated: (_) async {},
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '+359881234567');
    await tester.tap(find.text('ИЗПРАТИ КОД'));
    await started.future;
    await tester.pump();
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    response.complete(utf8JsonResponse(smsChallenge(), 202));
    await pumpSmsRoute(tester);
    expect(calls, 1);
  });

  testWidgets(
    'phone and verification labels update from Bulgarian to English',
    (tester) async {
      final service = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient(
          (request) async => utf8JsonResponse(smsChallenge(), 202),
        ),
        tokenStorage: PhoneScreenStorage(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PassengerPhoneAuthScreen(
            authService: service,
            onAuthenticated: (_) async {},
          ),
        ),
      );
      expect(find.text('Продължете с телефона си'), findsOneWidget);
      AppTranslations.currentLanguage = AppLanguage.english;
      await tester.pump();
      expect(find.text('Continue with your phone'), findsOneWidget);
      expect(find.text('Phone number'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '+359881234567');
      await tester.tap(find.text('SEND CODE'));
      await pumpSmsRoute(tester);
      expect(find.text('Verify your phone'), findsWidgets);
      expect(
        find.text('We sent a verification code to\n••••56'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'temporary verification failure is shown in the selected language',
    (tester) async {
      final service = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient((request) async {
          if (request.url.path == '/passenger/phone-verifications') {
            return utf8JsonResponse(smsChallenge(), 202);
          }
          throw http.ClientException('offline');
        }),
        tokenStorage: PhoneScreenStorage(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PassengerPhoneAuthScreen(
            authService: service,
            onAuthenticated: (_) async {},
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '+359881234567');
      await tester.tap(find.text('ИЗПРАТИ КОД'));
      await pumpSmsRoute(tester);
      await tester.enterText(smsCodeField(), '123456');
      await tester.pump();
      await tapVisible(tester, find.widgetWithText(ElevatedButton, 'ПОТВЪРДИ'));
      expect(
        find.text(
          'Няма връзка с интернет. Проверете връзката и опитайте отново.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
