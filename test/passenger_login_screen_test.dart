import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_app/localization/app_language.dart';
import 'package:taxi_app/localization/translations.dart';
import 'package:taxi_app/screens/passenger_login_screen.dart';
import 'package:taxi_app/services/passenger_auth_service.dart';

class LoginScreenTokenStorage implements PassengerTokenStorage {
  String? token;

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

void main() {
  setUp(() {
    AppTranslations.currentLanguage = AppLanguage.bulgarian;
  });

  testWidgets('shows Bulgarian credentials error for rejected login', (
    tester,
  ) async {
    final authService = PassengerAuthService(
      baseUrl: 'https://unit.test',
      client: MockClient((_) async => http.Response('{}', 401)),
      tokenStorage: LoginScreenTokenStorage(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PassengerLoginScreen(
          authService: authService,
          onAuthenticated: (_) async {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'city6_passenger_02');
    await tester.enterText(find.byType(TextField).at(1), 'synthetic-password');
    await tester.tap(find.text('ВХОД'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Потребителското име или паролата са грешни.'),
      findsOneWidget,
    );
  });

  testWidgets('shows Bulgarian connection message when the network is down', (
    tester,
  ) async {
    final authService = PassengerAuthService(
      baseUrl: 'https://unit.test',
      client: MockClient((_) async => throw http.ClientException('offline')),
      tokenStorage: LoginScreenTokenStorage(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PassengerLoginScreen(
          authService: authService,
          onAuthenticated: (_) async {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'city6_passenger_02');
    await tester.enterText(find.byType(TextField).at(1), 'synthetic-password');
    await tester.tap(find.text('ВХОД'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text(
        'Няма връзка с интернет. Проверете връзката и опитайте отново.',
      ),
      findsOneWidget,
    );
  });
}
