import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_app/services/passenger_auth_service.dart';

class MemoryPassengerTokenStorage implements PassengerTokenStorage {
  PassengerStoredCredentials? credentials;
  int writes = 0;
  bool failNextWrite = false;

  MemoryPassengerTokenStorage([this.credentials]);

  @override
  Future<PassengerStoredCredentials?> readCredentials() async => credentials;

  @override
  Future<void> writeCredentials(PassengerStoredCredentials value) async {
    writes++;
    if (failNextWrite) {
      failNextWrite = false;
      throw Exception('Synthetic secure-storage write failure.');
    }
    credentials = value;
  }

  @override
  Future<void> deleteCredentials() async => credentials = null;
}

Map<String, dynamic> tokenResponse({
  String id = 'passenger-profile-1',
  String? username,
  String token = 'access-token-1',
  String refreshToken = 'refresh-token-1',
  int expires = 43200,
}) => {
  'token': token,
  'tokenType': 'Bearer',
  'expiresInSeconds': expires,
  'refreshToken': refreshToken,
  'passenger': {'id': id, 'username': username, 'authMethod': 'phone'},
};

Map<String, dynamic> sessionResponse({
  String id = 'passenger-profile-1',
  String? username,
}) => {
  'authenticated': true,
  'passenger': {'id': id, 'username': username, 'authMethod': 'phone'},
};

Map<String, dynamic> challengeResponse({
  String id = 'challenge-1',
  String maskedPhone = '••••56',
  int expires = 600,
  int resendAfter = 60,
  int? remaining,
}) {
  final response = <String, dynamic>{
    'challengeId': id,
    'status': 'accepted',
    'maskedPhone': maskedPhone,
    'expiresInSeconds': expires,
    'resendAfterSeconds': resendAfter,
  };
  if (remaining != null) response['resendsRemaining'] = remaining;
  return response;
}

http.Response utf8JsonResponse(Map<String, dynamic> body, int statusCode) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  final now = DateTime.utc(2026, 11, 17, 12);

  test(
    'secure session record round trips tokens and pending refresh operation',
    () {
      const stored = PassengerStoredCredentials(
        accessToken: 'access-secret',
        refreshToken: 'refresh-secret',
        passengerId: 'stable-id',
        username: null,
        tokenType: 'Bearer',
        accessTokenExpiresAtEpochMs: 1800000000000,
        pendingRefreshRequestId: 'refresh-operation-id',
        pendingRefreshToken: 'refresh-secret',
      );
      final restored = PassengerStoredCredentials.fromJson(
        jsonDecode(jsonEncode(stored.toJson())),
      );
      expect(restored?.accessToken, 'access-secret');
      expect(restored?.refreshToken, 'refresh-secret');
      expect(restored?.passengerId, 'stable-id');
      expect(restored?.username, isNull);
      expect(restored?.pendingRefreshRequestId, 'refresh-operation-id');
      expect(restored?.pendingRefreshToken, 'refresh-secret');
    },
  );

  test(
    'Secure Storage keys isolate E2E credentials without moving old keys',
    () {
      expect(
        FlutterSecurePassengerTokenStorage.sessionKeyForNamespace('default'),
        'city6.passenger.session.v2',
      );
      expect(
        FlutterSecurePassengerTokenStorage.legacyTokenKeyForNamespace(
          'default',
        ),
        'city6.passenger.accessToken',
      );
      expect(
        FlutterSecurePassengerTokenStorage.sessionKeyForNamespace('e2e'),
        'city6.passenger.session.v2.e2e',
      );
      expect(
        FlutterSecurePassengerTokenStorage.legacyTokenKeyForNamespace('e2e'),
        'city6.passenger.accessToken.e2e',
      );
    },
  );

  test(
    'partially inconsistent refresh state is rejected from secure record',
    () {
      final missingCurrentToken = PassengerStoredCredentials.fromJson({
        'accessToken': 'access-token',
        'pendingRefreshRequestId': 'pending-id',
        'pendingRefreshToken': 'old-refresh-token',
      });
      final mismatchedCurrentToken = PassengerStoredCredentials.fromJson({
        'accessToken': 'access-token',
        'refreshToken': 'new-refresh-token',
        'pendingRefreshRequestId': 'pending-id',
        'pendingRefreshToken': 'old-refresh-token',
      });

      expect(missingCurrentToken, isNull);
      expect(mismatchedCurrentToken, isNull);
    },
  );

  test(
    'refresh is not sent if its pending operation cannot be persisted',
    () async {
      final storage = MemoryPassengerTokenStorage(
        PassengerStoredCredentials(
          accessToken: 'expired-access',
          refreshToken: 'refresh-token',
          passengerId: 'passenger-profile-1',
          accessTokenExpiresAtEpochMs: now
              .subtract(const Duration(seconds: 1))
              .millisecondsSinceEpoch,
        ),
      )..failNextWrite = true;
      var requests = 0;
      final service = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
        tokenStorage: storage,
        now: () => now,
        newUuid: () => 'pending-refresh-id',
      );

      await expectLater(
        service.restoreSession(),
        throwsA(
          isA<PassengerAuthException>().having(
            (error) => error.failure,
            'failure',
            PassengerAuthFailure.secureStorage,
          ),
        ),
      );
      expect(requests, 0);
      expect(storage.credentials?.pendingRefreshRequestId, isNull);
    },
  );

  test(
    'incomplete pending refresh state is rejected without a new request id',
    () async {
      final storage = MemoryPassengerTokenStorage(
        const PassengerStoredCredentials(
          accessToken: 'expired-access',
          refreshToken: 'refresh-token',
          passengerId: 'passenger-profile-1',
          accessTokenExpiresAtEpochMs: 1,
          pendingRefreshRequestId: 'already-persisted-id',
        ),
      );
      var requests = 0;
      final service = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
        tokenStorage: storage,
      );
      await expectLater(
        service.restoreSession(),
        throwsA(
          isA<PassengerAuthException>().having(
            (e) => e.failure,
            'failure',
            PassengerAuthFailure.secureStorage,
          ),
        ),
      );
      expect(requests, 0);
      expect(
        storage.credentials?.pendingRefreshRequestId,
        'already-persisted-id',
      );
    },
  );

  test(
    'international numbers are normalized and local numbers are rejected',
    () async {
      expect(
        PassengerAuthService.normalizeInternationalPhone('00359 (88) 123-4567'),
        '+359881234567',
      );
      expect(
        PassengerAuthService.normalizeInternationalPhone('+1 202 555 0144'),
        '+12025550144',
      );
      expect(
        PassengerAuthService.normalizeInternationalPhone('0881234567'),
        isNull,
      );
      expect(
        PassengerAuthService.normalizeInternationalPhone('+012345678'),
        isNull,
      );

      var requests = 0;
      final service = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 202);
        }),
        tokenStorage: MemoryPassengerTokenStorage(),
      );
      await expectLater(
        service.startPhoneVerification('0881234567'),
        throwsA(
          isA<PassengerAuthException>().having(
            (e) => e.failure,
            'failure',
            PassengerAuthFailure.invalidPhone,
          ),
        ),
      );
      expect(requests, 0);
    },
  );

  test(
    'phone verification start sends normalized phone and parses limits',
    () async {
      final service = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/passenger/phone-verifications');
          expect(jsonDecode(request.body), {'phoneNumber': '+359881234567'});
          return utf8JsonResponse(challengeResponse(remaining: 1), 202);
        }),
        tokenStorage: MemoryPassengerTokenStorage(),
      );

      final challenge = await service.startPhoneVerification(
        '00359 88 123 4567',
      );

      expect(challenge.challengeId, 'challenge-1');
      expect(challenge.maskedPhone, '••••56');
      expect(challenge.expiresInSeconds, 600);
      expect(challenge.resendAfterSeconds, 60);
      expect(challenge.resendsRemaining, 1);
    },
  );

  test(
    'legacy username login remains available for transition compatibility',
    () async {
      final storage = MemoryPassengerTokenStorage();
      final service = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient((request) async {
          expect(request.url.path, '/passenger/login');
          expect(jsonDecode(request.body), {
            'username': 'legacy-passenger',
            'password': 'synthetic-test-password',
          });
          return http.Response(
            jsonEncode({
              'token': 'legacy-access',
              'tokenType': 'Bearer',
              'expiresInSeconds': 43200,
              'refreshToken': 'legacy-refresh',
              'passenger': {
                'id': 44,
                'username': 'legacy-passenger',
                'authMethod': 'password',
              },
            }),
            200,
          );
        }),
        tokenStorage: storage,
        now: () => now,
      );
      final session = await service.login(
        username: ' legacy-passenger ',
        password: 'synthetic-test-password',
      );
      expect(session.passengerId, '44');
      expect(session.username, 'legacy-passenger');
      expect(storage.credentials?.refreshToken, 'legacy-refresh');
    },
  );

  test(
    'start maps backend rate limiting and temporary unavailability',
    () async {
      for (final entry in {
        429: PassengerAuthFailure.rateLimited,
        503: PassengerAuthFailure.backendUnavailable,
      }.entries) {
        final service = PassengerAuthService(
          baseUrl: 'https://unit.test',
          client: MockClient((_) async => http.Response('{}', entry.key)),
          tokenStorage: MemoryPassengerTokenStorage(),
        );
        await expectLater(
          service.startPhoneVerification('+359881234567'),
          throwsA(
            isA<PassengerAuthException>().having(
              (e) => e.failure,
              'failure',
              entry.value,
            ),
          ),
        );
      }
    },
  );

  test(
    'resend uses the challenge endpoint and enforces the send limit',
    () async {
      var calls = 0;
      final service = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient((request) async {
          calls++;
          expect(request.method, 'POST');
          expect(
            request.url.path,
            '/passenger/phone-verifications/challenge%2Fid/resend',
          );
          expect(request.body, isEmpty);
          return utf8JsonResponse(challengeResponse(), 202);
        }),
        tokenStorage: MemoryPassengerTokenStorage(),
      );
      final challenge = PassengerPhoneChallenge(
        challengeId: 'challenge/id',
        maskedPhone: '••••56',
        expiresInSeconds: 600,
        resendAfterSeconds: 0,
        resendsRemaining: 1,
      );

      final updated = await service.resendPhoneVerification(challenge);
      expect(updated.resendsRemaining, 0);
      await expectLater(
        service.resendPhoneVerification(updated),
        throwsA(
          isA<PassengerAuthException>().having(
            (e) => e.failure,
            'failure',
            PassengerAuthFailure.rateLimited,
          ),
        ),
      );
      expect(calls, 1);
    },
  );

  test(
    'verify accepts username null and saves the stable id with both tokens',
    () async {
      final storage = MemoryPassengerTokenStorage();
      final service = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.path,
            '/passenger/phone-verifications/challenge-1/verify',
          );
          expect(jsonDecode(request.body), {'code': '654321'});
          return http.Response(jsonEncode(tokenResponse()), 200);
        }),
        tokenStorage: storage,
        now: () => now,
      );
      final session = await service.verifyPhoneCode(
        challenge: PassengerPhoneChallenge(
          challengeId: 'challenge-1',
          maskedPhone: '••••56',
          expiresInSeconds: 600,
          resendAfterSeconds: 60,
        ),
        code: '654321',
      );

      expect(session.passengerId, 'passenger-profile-1');
      expect(session.username, isNull);
      expect(session.authMethod, 'phone');
      expect(session.authorizationHeader, 'Bearer access-token-1');
      expect(storage.credentials?.refreshToken, 'refresh-token-1');
      expect(storage.credentials?.passengerId, 'passenger-profile-1');
    },
  );

  test('malformed verification code never reaches Backend', () async {
    var requests = 0;
    final service = PassengerAuthService(
      baseUrl: 'https://unit.test',
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
      tokenStorage: MemoryPassengerTokenStorage(),
    );
    final challenge = PassengerPhoneChallenge(
      challengeId: 'challenge-1',
      maskedPhone: '••••56',
      expiresInSeconds: 600,
      resendAfterSeconds: 60,
    );
    await expectLater(
      service.verifyPhoneCode(challenge: challenge, code: '12'),
      throwsA(
        isA<PassengerAuthException>().having(
          (e) => e.failure,
          'failure',
          PassengerAuthFailure.invalidCode,
        ),
      ),
    );
    expect(requests, 0);
  });

  test(
    'invalid, expired and network verification responses are distinguished',
    () async {
      for (final entry in {
        401: PassengerAuthFailure.invalidCode,
        404: PassengerAuthFailure.challengeExpired,
        429: PassengerAuthFailure.rateLimited,
        503: PassengerAuthFailure.backendUnavailable,
      }.entries) {
        final service = PassengerAuthService(
          baseUrl: 'https://unit.test',
          client: MockClient((_) async => http.Response('{}', entry.key)),
          tokenStorage: MemoryPassengerTokenStorage(),
        );
        await expectLater(
          service.verifyPhoneCode(
            challenge: PassengerPhoneChallenge(
              challengeId: 'challenge-1',
              maskedPhone: '••••56',
              expiresInSeconds: 600,
              resendAfterSeconds: 60,
            ),
            code: '123456',
          ),
          throwsA(
            isA<PassengerAuthException>().having(
              (e) => e.failure,
              'failure',
              entry.value,
            ),
          ),
        );
      }
    },
  );

  test(
    'phone session restore accepts null username and preserves identity',
    () async {
      final storage = MemoryPassengerTokenStorage(
        PassengerStoredCredentials(
          accessToken: 'legacy-access-token',
          refreshToken: 'refresh-1',
          passengerId: 'passenger-profile-1',
          accessTokenExpiresAtEpochMs: now
              .add(const Duration(hours: 2))
              .millisecondsSinceEpoch,
        ),
      );
      final service = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient((request) async {
          expect(request.url.path, '/passenger/session');
          expect(
            request.headers['authorization'],
            'Bearer legacy-access-token',
          );
          return http.Response(jsonEncode(sessionResponse()), 200);
        }),
        tokenStorage: storage,
        now: () => now,
      );

      final restored = await service.restoreSession();
      expect(restored?.passengerId, 'passenger-profile-1');
      expect(restored?.username, isNull);
      expect(storage.credentials?.passengerId, 'passenger-profile-1');
      expect(storage.credentials?.refreshToken, 'refresh-1');
    },
  );

  test(
    'valid legacy access-only session is upgraded without replacing its id',
    () async {
      final storage = MemoryPassengerTokenStorage(
        const PassengerStoredCredentials(accessToken: 'old-access-token'),
      );
      final service = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient((request) async {
          expect(request.url.path, '/passenger/session');
          return http.Response(jsonEncode(sessionResponse()), 200);
        }),
        tokenStorage: storage,
        now: () => now,
      );
      final restored = await service.restoreSession();
      expect(restored?.passengerId, 'passenger-profile-1');
      expect(storage.credentials?.passengerId, 'passenger-profile-1');
      expect(storage.credentials?.refreshToken, isNull);
    },
  );

  test(
    'unauthorized access-only session is cleared without refresh retry',
    () async {
      final storage = MemoryPassengerTokenStorage(
        const PassengerStoredCredentials(accessToken: 'expired-legacy-token'),
      );
      var calls = 0;
      final service = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient((request) async {
          calls++;
          expect(request.url.path, '/passenger/session');
          return http.Response('{}', 401);
        }),
        tokenStorage: storage,
        now: () => now,
      );
      expect(await service.restoreSession(), isNull);
      expect(calls, 1);
      expect(storage.credentials, isNull);
    },
  );

  test(
    'access token 401 triggers one refresh and revalidates the session',
    () async {
      final storage = MemoryPassengerTokenStorage(
        PassengerStoredCredentials(
          accessToken: 'old-access-token',
          refreshToken: 'refresh-old',
          passengerId: 'passenger-profile-1',
          accessTokenExpiresAtEpochMs: now
              .add(const Duration(hours: 1))
              .millisecondsSinceEpoch,
        ),
      );
      var sessionCalls = 0;
      final service = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient((request) async {
          if (request.url.path == '/passenger/session') {
            sessionCalls++;
            if (sessionCalls == 1) return http.Response('{}', 401);
            expect(request.headers['authorization'], 'Bearer new-access-token');
            return http.Response(jsonEncode(sessionResponse()), 200);
          }
          expect(request.url.path, '/passenger/session/refresh');
          expect(jsonDecode(request.body)['refreshToken'], 'refresh-old');
          return http.Response(
            jsonEncode(
              tokenResponse(
                token: 'new-access-token',
                refreshToken: 'refresh-new',
              ),
            ),
            200,
          );
        }),
        tokenStorage: storage,
        now: () => now,
        newUuid: () => 'refresh-request-uuid',
      );

      final session = await service.restoreSession();
      expect(session?.passengerId, 'passenger-profile-1');
      expect(sessionCalls, 2);
      expect(storage.credentials?.refreshToken, 'refresh-new');
      expect(storage.credentials?.pendingRefreshRequestId, isNull);
    },
  );

  test(
    'pending refresh survives timeout and retries with the exact same id and token',
    () async {
      final storage = MemoryPassengerTokenStorage(
        PassengerStoredCredentials(
          accessToken: 'expired-access-token',
          refreshToken: 'refresh-original',
          passengerId: 'passenger-profile-1',
          accessTokenExpiresAtEpochMs: now
              .subtract(const Duration(seconds: 1))
              .millisecondsSinceEpoch,
        ),
      );
      final first = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient((request) async {
          expect(request.url.path, '/passenger/session/refresh');
          expect(
            storage.credentials?.pendingRefreshRequestId,
            'stable-refresh-id',
          );
          expect(storage.credentials?.pendingRefreshToken, 'refresh-original');
          throw http.ClientException('offline');
        }),
        tokenStorage: storage,
        now: () => now,
        newUuid: () => 'stable-refresh-id',
      );
      await expectLater(
        first.restoreSession(),
        throwsA(
          isA<PassengerAuthException>().having(
            (e) => e.failure,
            'failure',
            PassengerAuthFailure.networkUnavailable,
          ),
        ),
      );
      final savedPendingId = storage.credentials?.pendingRefreshRequestId;
      final savedPendingToken = storage.credentials?.pendingRefreshToken;
      expect(savedPendingId, 'stable-refresh-id');
      expect(savedPendingToken, 'refresh-original');

      final retryBodies = <Map<String, dynamic>>[];
      final retry = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient((request) async {
          if (request.url.path == '/passenger/session/refresh') {
            retryBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
            return http.Response(
              jsonEncode(
                tokenResponse(
                  token: 'rotated-access',
                  refreshToken: 'rotated-refresh',
                ),
              ),
              200,
            );
          }
          expect(request.url.path, '/passenger/session');
          return http.Response(jsonEncode(sessionResponse()), 200);
        }),
        tokenStorage: storage,
        now: () => now,
        newUuid: () => 'must-not-be-used',
      );
      final restored = await retry.restoreSession();
      expect(restored?.passengerId, 'passenger-profile-1');
      expect(retryBodies, [
        {'refreshToken': savedPendingToken, 'refreshRequestId': savedPendingId},
      ]);
      expect(storage.credentials?.pendingRefreshRequestId, isNull);
      expect(storage.credentials?.refreshToken, 'rotated-refresh');
    },
  );

  test(
    'concurrent auth header requests share one serialized refresh',
    () async {
      final storage = MemoryPassengerTokenStorage(
        PassengerStoredCredentials(
          accessToken: 'soon-expired-access',
          refreshToken: 'refresh-current',
          passengerId: 'passenger-profile-1',
          accessTokenExpiresAtEpochMs: now
              .add(const Duration(seconds: 10))
              .millisecondsSinceEpoch,
        ),
      );
      final response = Completer<http.Response>();
      final refreshStarted = Completer<void>();
      var refreshCalls = 0;
      final service = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient((request) async {
          refreshCalls++;
          refreshStarted.complete();
          return response.future;
        }),
        tokenStorage: storage,
        now: () => now,
        newUuid: () => 'shared-refresh-id',
      );

      final first = service.authorizationHeader();
      final second = service.authorizationHeader();
      await refreshStarted.future;
      response.complete(
        http.Response(
          jsonEncode(
            tokenResponse(token: 'new-access', refreshToken: 'new-refresh'),
          ),
          200,
        ),
      );
      expect(await first, 'Bearer new-access');
      expect(await second, 'Bearer new-access');
      expect(refreshCalls, 1);
    },
  );

  test(
    'temporary refresh outage may use an access token only while it is valid',
    () async {
      final storage = MemoryPassengerTokenStorage(
        PassengerStoredCredentials(
          accessToken: 'still-valid-access',
          refreshToken: 'refresh-token',
          passengerId: 'passenger-profile-1',
          accessTokenExpiresAtEpochMs: now
              .add(const Duration(seconds: 30))
              .millisecondsSinceEpoch,
        ),
      );
      final service = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient((request) async {
          expect(request.url.path, '/passenger/session/refresh');
          return http.Response('{}', 503);
        }),
        tokenStorage: storage,
        now: () => now,
        newUuid: () => 'stable-pending-id',
      );

      expect(await service.authorizationHeader(), 'Bearer still-valid-access');
      expect(storage.credentials?.pendingRefreshRequestId, 'stable-pending-id');
    },
  );

  test(
    'refresh 401 clears a revoked session instead of retrying forever',
    () async {
      final storage = MemoryPassengerTokenStorage(
        PassengerStoredCredentials(
          accessToken: 'expired-access',
          refreshToken: 'revoked-refresh',
          passengerId: 'passenger-profile-1',
          accessTokenExpiresAtEpochMs: now
              .subtract(const Duration(seconds: 1))
              .millisecondsSinceEpoch,
        ),
      );
      var calls = 0;
      final service = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient((request) async {
          calls++;
          expect(request.url.path, '/passenger/session/refresh');
          return http.Response('{}', 401);
        }),
        tokenStorage: storage,
        now: () => now,
        newUuid: () => 'revoke-check-id',
      );
      expect(await service.restoreSession(), isNull);
      expect(storage.credentials, isNull);
      expect(calls, 1);
    },
  );

  test(
    'session restore never switches the stored passenger identity',
    () async {
      final storage = MemoryPassengerTokenStorage(
        PassengerStoredCredentials(
          accessToken: 'access-token',
          passengerId: 'passenger-profile-1',
          accessTokenExpiresAtEpochMs: now
              .add(const Duration(hours: 1))
              .millisecondsSinceEpoch,
        ),
      );
      final service = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(sessionResponse(id: 'passenger-profile-2')),
            200,
          ),
        ),
        tokenStorage: storage,
        now: () => now,
      );
      await expectLater(
        service.restoreSession(),
        throwsA(
          isA<PassengerAuthException>().having(
            (e) => e.failure,
            'failure',
            PassengerAuthFailure.invalidResponse,
          ),
        ),
      );
      expect(storage.credentials?.passengerId, 'passenger-profile-1');
    },
  );

  test(
    'activity uses Bearer token and a unique id for each real event call',
    () async {
      final storage = MemoryPassengerTokenStorage(
        const PassengerStoredCredentials(accessToken: 'activity-access'),
      );
      final events = <Map<String, dynamic>>[];
      var eventSequence = 0;
      final service = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient((request) async {
          expect(request.url.path, '/passenger/session/activity');
          expect(request.headers['authorization'], 'Bearer activity-access');
          events.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response('{"recorded":true,"duplicate":false}', 200);
        }),
        tokenStorage: storage,
        newUuid: () => 'activity-${++eventSequence}',
      );
      await service.recordActivity('foreground');
      await service.recordActivity('interaction');
      expect(events, [
        {'eventId': 'activity-1', 'activityType': 'foreground'},
        {'eventId': 'activity-2', 'activityType': 'interaction'},
      ]);
    },
  );

  test(
    'logout clears local credentials and reports uncertain remote revoke',
    () async {
      final storage = MemoryPassengerTokenStorage(
        const PassengerStoredCredentials(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
        ),
      );
      final service = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/passenger/session/logout');
          expect(jsonDecode(request.body), {'refreshToken': 'refresh-token'});
          throw http.ClientException('offline');
        }),
        tokenStorage: storage,
      );
      expect(await service.logout(), isFalse);
      expect(storage.credentials, isNull);
      expect(service.currentSession, isNull);
      expect(await service.authorizationHeader(), isNull);
    },
  );

  test(
    'legacy session without refresh token signs out locally without claiming revoke',
    () async {
      final storage = MemoryPassengerTokenStorage(
        const PassengerStoredCredentials(accessToken: 'legacy-token'),
      );
      final service = PassengerAuthService(
        baseUrl: 'https://unit.test',
        client: MockClient(
          (_) async => fail('Legacy sessions have no refresh token.'),
        ),
        tokenStorage: storage,
      );
      expect(await service.logout(), isFalse);
      expect(storage.credentials, isNull);
    },
  );

  test('logout confirms server revoke before reporting it', () async {
    final storage = MemoryPassengerTokenStorage(
      const PassengerStoredCredentials(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
    );
    final service = PassengerAuthService(
      baseUrl: 'https://unit.test',
      client: MockClient((request) async {
        expect(request.url.path, '/passenger/session/logout');
        expect(jsonDecode(request.body), {'refreshToken': 'refresh-token'});
        return http.Response('{"loggedOut":true}', 200);
      }),
      tokenStorage: storage,
    );
    expect(await service.logout(), isTrue);
    expect(storage.credentials, isNull);
  });
}
