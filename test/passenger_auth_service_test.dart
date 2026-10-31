import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_app/services/passenger_auth_service.dart';

class MemoryPassengerTokenStorage implements PassengerTokenStorage {
  String? token;

  MemoryPassengerTokenStorage([this.token]);

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

Map<String, dynamic> loginResponse({
  String username = 'city6_passenger_01',
  int id = 101,
}) {
  return {
    'token': 'synthetic-test-token',
    'tokenType': 'Bearer',
    'expiresInSeconds': 3600,
    'passenger': {'id': id, 'username': username},
  };
}

void main() {
  test(
    'login persists only the access token through secure storage adapter',
    () async {
      final storage = MemoryPassengerTokenStorage();
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/passenger/login');
        expect(request.headers['content-type'], contains('application/json'));
        expect(jsonDecode(request.body), {
          'username': 'city6_passenger_01',
          'password': 'synthetic-password',
        });
        return http.Response(jsonEncode(loginResponse()), 200);
      });
      final service = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: client,
        tokenStorage: storage,
      );

      final session = await service.login(
        username: ' city6_passenger_01 ',
        password: 'synthetic-password',
      );

      expect(session.passengerId, '101');
      expect(session.username, 'city6_passenger_01');
      expect(session.authorizationHeader, 'Bearer synthetic-test-token');
      expect(storage.token, 'synthetic-test-token');
    },
  );

  test(
    'login reports invalid credentials without persisting a token',
    () async {
      final storage = MemoryPassengerTokenStorage();
      final service = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient((_) async => http.Response('{}', 401)),
        tokenStorage: storage,
      );

      await expectLater(
        service.login(username: 'city6_passenger_02', password: 'wrong'),
        throwsA(
          isA<PassengerAuthException>().having(
            (error) => error.failure,
            'failure',
            PassengerAuthFailure.invalidCredentials,
          ),
        ),
      );
      expect(storage.token, isNull);
    },
  );

  test(
    'saved token restores identity after creating a new auth service',
    () async {
      final storage = MemoryPassengerTokenStorage();
      final loginService = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient(
          (_) async => http.Response(jsonEncode(loginResponse()), 200),
        ),
        tokenStorage: storage,
      );
      await loginService.login(
        username: 'city6_passenger_01',
        password: 'synthetic-password',
      );

      final restoredService = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/passenger/session');
          expect(
            request.headers['authorization'],
            'Bearer synthetic-test-token',
          );
          return http.Response(
            jsonEncode({
              'authenticated': true,
              'passenger': {'id': 101, 'username': 'city6_passenger_01'},
            }),
            200,
          );
        }),
        tokenStorage: storage,
      );

      final restored = await restoredService.restoreSession();
      expect(restored?.passengerId, '101');
      expect(restored?.username, 'city6_passenger_01');
      expect(storage.token, 'synthetic-test-token');
    },
  );

  test('expired token is deleted after session endpoint returns 401', () async {
    final storage = MemoryPassengerTokenStorage('expired-test-token');
    final service = PassengerAuthService(
      baseUrl: 'https://unit.test',
      client: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer expired-test-token');
        return http.Response('{}', 401);
      }),
      tokenStorage: storage,
    );

    expect(await service.restoreSession(), isNull);
    expect(storage.token, isNull);
    expect(service.currentSession, isNull);
  });

  test('temporary backend outage preserves token for later retry', () async {
    final storage = MemoryPassengerTokenStorage('saved-test-token');
    final service = PassengerAuthService(
      baseUrl: 'https://unit.test',
      client: MockClient((_) async => http.Response('{}', 503)),
      tokenStorage: storage,
    );

    await expectLater(
      service.restoreSession(),
      throwsA(
        isA<PassengerAuthException>().having(
          (error) => error.failure,
          'failure',
          PassengerAuthFailure.backendUnavailable,
        ),
      ),
    );
    expect(storage.token, 'saved-test-token');
  });

  test('logout removes token and in-memory identity', () async {
    final storage = MemoryPassengerTokenStorage();
    final service = PassengerAuthService(
      baseUrl: 'https://unit.test',
      client: MockClient(
        (_) async => http.Response(jsonEncode(loginResponse()), 200),
      ),
      tokenStorage: storage,
    );
    await service.login(
      username: 'city6_passenger_01',
      password: 'synthetic-password',
    );

    await service.logout();

    expect(storage.token, isNull);
    expect(service.currentSession, isNull);
    expect(await service.authorizationHeader(), isNull);
  });
}
