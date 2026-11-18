import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../config/backend_config.dart';
import '../models/passenger_session.dart';

enum PassengerAuthFailure {
  invalidCredentials,
  invalidPhone,
  invalidCode,
  challengeExpired,
  rateLimited,
  networkUnavailable,
  backendUnavailable,
  sessionExpired,
  invalidResponse,
  secureStorage,
}

class PassengerAuthException implements Exception {
  final PassengerAuthFailure failure;

  const PassengerAuthException(this.failure);
}

class PassengerPhoneChallenge {
  final String challengeId;
  final String maskedPhone;
  final int expiresInSeconds;
  final int resendAfterSeconds;
  final int resendsRemaining;

  const PassengerPhoneChallenge({
    required this.challengeId,
    required this.maskedPhone,
    required this.expiresInSeconds,
    required this.resendAfterSeconds,
    this.resendsRemaining = 2,
  });

  PassengerPhoneChallenge copyWith({
    int? expiresInSeconds,
    int? resendAfterSeconds,
    int? resendsRemaining,
  }) => PassengerPhoneChallenge(
    challengeId: challengeId,
    maskedPhone: maskedPhone,
    expiresInSeconds: expiresInSeconds ?? this.expiresInSeconds,
    resendAfterSeconds: resendAfterSeconds ?? this.resendAfterSeconds,
    resendsRemaining: resendsRemaining ?? this.resendsRemaining,
  );
}

class PassengerStoredCredentials {
  final String accessToken;
  final String? refreshToken;
  final String? passengerId;
  final String? username;
  final String tokenType;
  final int? accessTokenExpiresAtEpochMs;
  final String? pendingRefreshRequestId;
  final String? pendingRefreshToken;

  const PassengerStoredCredentials({
    required this.accessToken,
    this.refreshToken,
    this.passengerId,
    this.username,
    this.tokenType = 'Bearer',
    this.accessTokenExpiresAtEpochMs,
    this.pendingRefreshRequestId,
    this.pendingRefreshToken,
  });

  DateTime? get accessTokenExpiresAt => accessTokenExpiresAtEpochMs == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(
          accessTokenExpiresAtEpochMs!,
          isUtc: true,
        );

  PassengerStoredCredentials copyWith({
    String? accessToken,
    String? refreshToken,
    String? passengerId,
    String? username,
    String? tokenType,
    int? accessTokenExpiresAtEpochMs,
    String? pendingRefreshRequestId,
    String? pendingRefreshToken,
    bool clearPendingRefresh = false,
  }) => PassengerStoredCredentials(
    accessToken: accessToken ?? this.accessToken,
    refreshToken: refreshToken ?? this.refreshToken,
    passengerId: passengerId ?? this.passengerId,
    username: username ?? this.username,
    tokenType: tokenType ?? this.tokenType,
    accessTokenExpiresAtEpochMs:
        accessTokenExpiresAtEpochMs ?? this.accessTokenExpiresAtEpochMs,
    pendingRefreshRequestId: clearPendingRefresh
        ? null
        : pendingRefreshRequestId ?? this.pendingRefreshRequestId,
    pendingRefreshToken: clearPendingRefresh
        ? null
        : pendingRefreshToken ?? this.pendingRefreshToken,
  );

  Map<String, Object?> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'passengerId': passengerId,
    'username': username,
    'tokenType': tokenType,
    'accessTokenExpiresAtEpochMs': accessTokenExpiresAtEpochMs,
    'pendingRefreshRequestId': pendingRefreshRequestId,
    'pendingRefreshToken': pendingRefreshToken,
  };

  static PassengerStoredCredentials? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final accessToken = value['accessToken'];
    if (accessToken is! String || accessToken.trim().isEmpty) return null;
    final refreshToken = value['refreshToken'];
    final passengerId = value['passengerId'];
    final username = value['username'];
    final tokenType = value['tokenType'];
    final expiration = value['accessTokenExpiresAtEpochMs'];
    final pendingId = value['pendingRefreshRequestId'];
    final pendingToken = value['pendingRefreshToken'];
    if ((refreshToken != null && refreshToken is! String) ||
        (passengerId != null && passengerId is! String) ||
        (username != null && username is! String) ||
        (tokenType != null && tokenType is! String) ||
        (expiration != null && expiration is! int) ||
        (pendingId != null && pendingId is! String) ||
        (pendingToken != null && pendingToken is! String)) {
      return null;
    }
    if ((pendingId == null) != (pendingToken == null) ||
        (pendingId != null &&
            (pendingId.trim().isEmpty ||
                pendingToken!.trim().isEmpty ||
                refreshToken != pendingToken))) {
      return null;
    }
    return PassengerStoredCredentials(
      accessToken: accessToken,
      refreshToken: refreshToken as String?,
      passengerId: passengerId as String?,
      username: username as String?,
      tokenType: tokenType as String? ?? 'Bearer',
      accessTokenExpiresAtEpochMs: expiration as int?,
      pendingRefreshRequestId: pendingId as String?,
      pendingRefreshToken: pendingToken as String?,
    );
  }
}

abstract interface class PassengerTokenStorage {
  Future<PassengerStoredCredentials?> readCredentials();
  Future<void> writeCredentials(PassengerStoredCredentials credentials);
  Future<void> deleteCredentials();
}

class FlutterSecurePassengerTokenStorage implements PassengerTokenStorage {
  static const String _sessionKey = 'city6.passenger.session.v2';
  static const String _legacyTokenKey = 'city6.passenger.accessToken';

  final FlutterSecureStorage storage;

  const FlutterSecurePassengerTokenStorage({
    this.storage = const FlutterSecureStorage(),
  });

  @override
  Future<PassengerStoredCredentials?> readCredentials() async {
    final sessionJson = await storage.read(key: _sessionKey);
    if (sessionJson != null) {
      try {
        final credentials = PassengerStoredCredentials.fromJson(
          jsonDecode(sessionJson),
        );
        if (credentials == null) {
          throw const FormatException('Saved Passenger session is incomplete.');
        }
        return credentials;
      } on FormatException {
        throw const PassengerAuthException(PassengerAuthFailure.secureStorage);
      }
    }

    // Upgrade the previous access-token-only installation only after the
    // Backend verifies it. The legacy value is not removed at this stage.
    final legacyToken = await storage.read(key: _legacyTokenKey);
    if (legacyToken == null || legacyToken.trim().isEmpty) return null;
    return PassengerStoredCredentials(
      accessToken: legacyToken,
      accessTokenExpiresAtEpochMs: _readJwtExpiration(legacyToken),
    );
  }

  @override
  Future<void> writeCredentials(PassengerStoredCredentials credentials) async {
    // One secure-storage value keeps rotated tokens and a pending idempotent
    // refresh operation together across process death.
    await storage.write(
      key: _sessionKey,
      value: jsonEncode(credentials.toJson()),
    );
    await storage.delete(key: _legacyTokenKey);
  }

  @override
  Future<void> deleteCredentials() async {
    await storage.delete(key: _sessionKey);
    await storage.delete(key: _legacyTokenKey);
  }

  static int? _readJwtExpiration(String token) {
    try {
      final pieces = token.split('.');
      if (pieces.length != 3) return null;
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(pieces[1])),
      );
      final decoded = jsonDecode(payload);
      final exp = decoded is Map<String, dynamic> ? decoded['exp'] : null;
      return exp is int ? exp * 1000 : null;
    } on Object {
      return null;
    }
  }
}

class PassengerAuthService {
  static const Uuid _uuid = Uuid();
  static const Duration _refreshWindow = Duration(minutes: 2);

  final String? baseUrl;
  final http.Client client;
  final PassengerTokenStorage tokenStorage;
  final Duration requestTimeout;
  final DateTime Function() _now;
  final String Function() _newUuid;

  PassengerStoredCredentials? _credentials;
  Future<PassengerStoredCredentials?>? _refreshInFlight;
  PassengerSession? currentSession;

  PassengerAuthService({
    this.baseUrl,
    http.Client? client,
    PassengerTokenStorage? tokenStorage,
    this.requestTimeout = const Duration(seconds: 10),
    DateTime Function()? now,
    String Function()? newUuid,
  }) : client = client ?? http.Client(),
       tokenStorage =
           tokenStorage ?? const FlutterSecurePassengerTokenStorage(),
       _now = now ?? DateTime.now,
       _newUuid = newUuid ?? _uuid.v4;

  String get _baseUrl => baseUrl ?? BackendConfig.baseUrl;

  Future<PassengerPhoneChallenge> startPhoneVerification(
    String phoneNumber,
  ) async {
    final normalizedPhone = normalizeInternationalPhone(phoneNumber);
    if (normalizedPhone == null) {
      throw const PassengerAuthException(PassengerAuthFailure.invalidPhone);
    }
    final response = await _send(
      'POST',
      '/passenger/phone-verifications',
      body: {'phoneNumber': normalizedPhone},
    );
    if (response.statusCode == 400) _throw(PassengerAuthFailure.invalidPhone);
    if (response.statusCode == 429) _throw(PassengerAuthFailure.rateLimited);
    if (response.statusCode == 503 || response.statusCode >= 500) {
      _throw(PassengerAuthFailure.backendUnavailable);
    }
    if (response.statusCode != 202) {
      _throw(PassengerAuthFailure.invalidResponse);
    }
    return _parseChallenge(response.bodyBytes);
  }

  Future<PassengerPhoneChallenge> resendPhoneVerification(
    PassengerPhoneChallenge challenge,
  ) async {
    if (challenge.resendsRemaining <= 0) {
      _throw(PassengerAuthFailure.rateLimited);
    }
    final response = await _send(
      'POST',
      '/passenger/phone-verifications/${Uri.encodeComponent(challenge.challengeId)}/resend',
    );
    if (response.statusCode == 404) {
      _throw(PassengerAuthFailure.challengeExpired);
    }
    if (response.statusCode == 429) _throw(PassengerAuthFailure.rateLimited);
    if (response.statusCode == 503 || response.statusCode >= 500) {
      _throw(PassengerAuthFailure.backendUnavailable);
    }
    if (response.statusCode != 202) {
      _throw(PassengerAuthFailure.invalidResponse);
    }
    final parsed = _parseChallenge(response.bodyBytes);
    final serverRemaining = parsed.resendsRemaining;
    return parsed.copyWith(
      resendsRemaining: serverRemaining < challenge.resendsRemaining
          ? serverRemaining
          : challenge.resendsRemaining - 1,
    );
  }

  Future<PassengerSession> verifyPhoneCode({
    required PassengerPhoneChallenge challenge,
    required String code,
  }) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _throw(PassengerAuthFailure.invalidCode);
    }
    final response = await _send(
      'POST',
      '/passenger/phone-verifications/${Uri.encodeComponent(challenge.challengeId)}/verify',
      body: {'code': code},
    );
    if (response.statusCode == 401) _throw(PassengerAuthFailure.invalidCode);
    if (response.statusCode == 404) {
      _throw(PassengerAuthFailure.challengeExpired);
    }
    if (response.statusCode == 429) _throw(PassengerAuthFailure.rateLimited);
    if (response.statusCode == 503 || response.statusCode >= 500) {
      _throw(PassengerAuthFailure.backendUnavailable);
    }
    if (response.statusCode != 200) {
      _throw(PassengerAuthFailure.invalidResponse);
    }
    final session = _parseTokenResponse(
      response.bodyBytes,
      requireRefresh: true,
    );
    await _persistSession(session);
    return session;
  }

  /// Kept only for transition compatibility with the legacy Backend endpoint.
  /// This method is not exposed by the public Passenger authentication UI.
  Future<PassengerSession> login({
    required String username,
    required String password,
  }) async {
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty || password.isEmpty) {
      throw const PassengerAuthException(
        PassengerAuthFailure.invalidCredentials,
      );
    }
    final response = await _send(
      'POST',
      '/passenger/login',
      body: {'username': normalizedUsername, 'password': password},
    );
    if (response.statusCode == 401) {
      _throw(PassengerAuthFailure.invalidCredentials);
    }
    if (response.statusCode == 408 ||
        response.statusCode == 429 ||
        response.statusCode >= 500) {
      _throw(PassengerAuthFailure.backendUnavailable);
    }
    if (response.statusCode != 200) {
      _throw(PassengerAuthFailure.invalidResponse);
    }
    final session = _parseTokenResponse(
      response.bodyBytes,
      requireRefresh: false,
    );
    await _persistSession(session);
    return session;
  }

  Future<PassengerSession?> restoreSession() async {
    var credentials = await _readCredentials();
    if (credentials == null) {
      _credentials = null;
      currentSession = null;
      return null;
    }

    if (credentials.refreshToken != null &&
        credentials.pendingRefreshRequestId != null) {
      credentials = await _refreshCredentials();
      if (credentials == null) return null;
    } else if (_shouldRefresh(credentials)) {
      credentials = await _refreshCredentials();
      if (credentials == null) return null;
    }

    var sessionResponse = await _getSession(credentials);
    if ((sessionResponse.statusCode == 401 ||
            sessionResponse.statusCode == 403) &&
        credentials.refreshToken != null) {
      credentials = await _refreshCredentials();
      if (credentials == null) return null;
      sessionResponse = await _getSession(credentials);
    }

    if (sessionResponse.statusCode == 401 ||
        sessionResponse.statusCode == 403) {
      await _clearCredentials();
      return null;
    }
    if (sessionResponse.statusCode == 408 ||
        sessionResponse.statusCode == 429 ||
        sessionResponse.statusCode >= 500) {
      _throw(PassengerAuthFailure.backendUnavailable);
    }
    if (sessionResponse.statusCode != 200) {
      _throw(PassengerAuthFailure.invalidResponse);
    }

    final restored = _parseSessionResponse(
      sessionResponse.bodyBytes,
      credentials,
    );
    if (credentials.passengerId != null &&
        credentials.passengerId != restored.passengerId) {
      _throw(PassengerAuthFailure.invalidResponse);
    }
    final upgraded = PassengerStoredCredentials(
      accessToken: credentials.accessToken,
      refreshToken: credentials.refreshToken,
      passengerId: restored.passengerId,
      username: restored.username,
      tokenType: credentials.tokenType,
      accessTokenExpiresAtEpochMs:
          credentials.accessTokenExpiresAtEpochMs ??
          _jwtExpiryEpochMs(credentials.accessToken),
      pendingRefreshRequestId: credentials.pendingRefreshRequestId,
      pendingRefreshToken: credentials.pendingRefreshToken,
    );
    await _writeCredentials(upgraded);
    _credentials = upgraded;
    currentSession = restored;
    return restored;
  }

  Future<String?> authorizationHeader() async {
    final savedCredentials = _credentials ?? await _readCredentials();
    if (savedCredentials == null) return null;
    var credentials = savedCredentials;
    if (_shouldRefresh(savedCredentials)) {
      try {
        final refreshed = await _refreshCredentials();
        if (refreshed == null) {
          _throw(PassengerAuthFailure.sessionExpired);
        }
        credentials = refreshed;
      } on PassengerAuthException catch (error) {
        final stillValid = savedCredentials.accessTokenExpiresAt?.isAfter(
          _now().toUtc(),
        );
        if (stillValid == true &&
            (error.failure == PassengerAuthFailure.networkUnavailable ||
                error.failure == PassengerAuthFailure.backendUnavailable)) {
          return '${savedCredentials.tokenType} ${savedCredentials.accessToken}';
        }
        rethrow;
      }
    }
    return '${credentials.tokenType} ${credentials.accessToken}';
  }

  Future<void> recordActivity(String activityType) async {
    if (activityType != 'foreground' && activityType != 'interaction') {
      throw ArgumentError.value(activityType, 'activityType');
    }
    final authorization = await authorizationHeader();
    if (authorization == null) return;
    final response = await _send(
      'POST',
      '/passenger/session/activity',
      headers: {'Authorization': authorization},
      body: {'eventId': _newUuid(), 'activityType': activityType},
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      _throw(PassengerAuthFailure.sessionExpired);
    }
    if (response.statusCode == 429) _throw(PassengerAuthFailure.rateLimited);
    if (response.statusCode == 408 || response.statusCode >= 500) {
      _throw(PassengerAuthFailure.backendUnavailable);
    }
    if (response.statusCode != 200) {
      _throw(PassengerAuthFailure.invalidResponse);
    }
  }

  /// Revokes the server session when possible, then clears local credentials.
  /// The return value is false when local logout succeeded but server revoke
  /// could not be confirmed (or a legacy token has no refresh credential).
  Future<bool> logout() async {
    final credentials = _credentials ?? await _readCredentials();
    var serverRevoked = false;
    if (credentials?.refreshToken != null) {
      try {
        final response = await _send(
          'POST',
          '/passenger/session/logout',
          body: {'refreshToken': credentials!.refreshToken},
        );
        if (response.statusCode == 200) {
          try {
            serverRevoked =
                _decodeObject(response.bodyBytes)['loggedOut'] == true;
          } on Exception {
            serverRevoked = false;
          }
        }
      } on PassengerAuthException {
        serverRevoked = false;
      }
    }
    await _clearCredentials();
    return serverRevoked;
  }

  bool _shouldRefresh(PassengerStoredCredentials credentials) {
    final expiresAt = credentials.accessTokenExpiresAt;
    return credentials.refreshToken != null &&
        expiresAt != null &&
        !expiresAt.isAfter(_now().toUtc().add(_refreshWindow));
  }

  Future<PassengerStoredCredentials?> _refreshCredentials() {
    final current = _refreshInFlight;
    if (current != null) return current;
    final future = _performRefresh();
    _refreshInFlight = future;
    return future.whenComplete(() {
      if (identical(_refreshInFlight, future)) _refreshInFlight = null;
    });
  }

  Future<PassengerStoredCredentials?> _performRefresh() async {
    var credentials = _credentials ?? await _readCredentials();
    if (credentials == null || credentials.refreshToken == null) return null;
    var pendingId = credentials.pendingRefreshRequestId;
    var pendingToken = credentials.pendingRefreshToken;
    if ((pendingId == null) != (pendingToken == null)) {
      _throw(PassengerAuthFailure.secureStorage);
    }
    if (pendingId == null || pendingToken == null) {
      pendingId = _newUuid();
      pendingToken = credentials.refreshToken;
      credentials = credentials.copyWith(
        pendingRefreshRequestId: pendingId,
        pendingRefreshToken: pendingToken,
      );
      await _writeCredentials(credentials);
      _credentials = credentials;
    }
    if (pendingToken != credentials.refreshToken) {
      _throw(PassengerAuthFailure.secureStorage);
    }

    final response = await _send(
      'POST',
      '/passenger/session/refresh',
      body: {'refreshToken': pendingToken, 'refreshRequestId': pendingId},
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      await _clearCredentials();
      return null;
    }
    if (response.statusCode == 408 ||
        response.statusCode == 429 ||
        response.statusCode >= 500) {
      _throw(PassengerAuthFailure.backendUnavailable);
    }
    if (response.statusCode != 200) {
      _throw(PassengerAuthFailure.invalidResponse);
    }

    final refreshed = _parseTokenResponse(
      response.bodyBytes,
      requireRefresh: true,
    );
    if (credentials.passengerId != null &&
        credentials.passengerId != refreshed.passengerId) {
      _throw(PassengerAuthFailure.invalidResponse);
    }
    final nextCredentials = PassengerStoredCredentials(
      accessToken: refreshed.accessToken,
      refreshToken: refreshed.refreshToken,
      passengerId: refreshed.passengerId,
      username: refreshed.username,
      tokenType: refreshed.tokenType,
      accessTokenExpiresAtEpochMs: _expiryEpochMs(refreshed.expiresInSeconds),
    );
    await _writeCredentials(nextCredentials);
    _credentials = nextCredentials;
    currentSession = refreshed;
    return nextCredentials;
  }

  Future<http.Response> _getSession(PassengerStoredCredentials credentials) {
    return _send(
      'GET',
      '/passenger/session',
      headers: {
        'Authorization': '${credentials.tokenType} ${credentials.accessToken}',
      },
    );
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String> headers = const {},
    Map<String, Object?>? body,
  }) async {
    try {
      final requestHeaders = <String, String>{
        'Accept': 'application/json',
        ...headers,
        if (body != null) 'Content-Type': 'application/json; charset=utf-8',
      };
      final request = http.Request(method, Uri.parse('$_baseUrl$path'))
        ..headers.addAll(requestHeaders);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await client.send(request).timeout(requestTimeout);
      return await http.Response.fromStream(streamed).timeout(requestTimeout);
    } on PassengerAuthException {
      rethrow;
    } on TimeoutException {
      _throw(PassengerAuthFailure.networkUnavailable);
    } on http.ClientException {
      _throw(PassengerAuthFailure.networkUnavailable);
    } on Exception {
      _throw(PassengerAuthFailure.networkUnavailable);
    }
  }

  PassengerPhoneChallenge _parseChallenge(List<int> bodyBytes) {
    try {
      final decoded = _decodeObject(bodyBytes);
      final id = decoded['challengeId'];
      final status = decoded['status'];
      final masked = decoded['maskedPhone'];
      final expires = decoded['expiresInSeconds'];
      final resendAfter = decoded['resendAfterSeconds'];
      final remaining = decoded['resendsRemaining'];
      if (id is! String ||
          id.trim().isEmpty ||
          status != 'accepted' ||
          masked is! String ||
          masked.trim().isEmpty ||
          expires is! int ||
          expires <= 0 ||
          resendAfter is! int ||
          resendAfter < 0 ||
          (remaining != null && (remaining is! int || remaining < 0))) {
        throw const FormatException('Invalid phone challenge response.');
      }
      return PassengerPhoneChallenge(
        challengeId: id,
        maskedPhone: masked,
        expiresInSeconds: expires,
        resendAfterSeconds: resendAfter,
        resendsRemaining: remaining as int? ?? 2,
      );
    } on Exception {
      _throw(PassengerAuthFailure.invalidResponse);
    }
  }

  PassengerSession _parseTokenResponse(
    List<int> bodyBytes, {
    required bool requireRefresh,
  }) {
    try {
      final decoded = _decodeObject(bodyBytes);
      final token = decoded['token'];
      final tokenType = decoded['tokenType'];
      final expires = decoded['expiresInSeconds'];
      final refreshToken = decoded['refreshToken'];
      if (token is! String ||
          token.trim().isEmpty ||
          tokenType is! String ||
          tokenType.toLowerCase() != 'bearer' ||
          expires is! int ||
          expires <= 0 ||
          (requireRefresh &&
              (refreshToken is! String || refreshToken.trim().isEmpty)) ||
          (refreshToken != null && refreshToken is! String)) {
        throw const FormatException('Invalid token response.');
      }
      final session = _parsePassenger(
        decoded['passenger'],
        token: token,
        tokenType: tokenType,
        expiresInSeconds: expires,
        refreshToken: refreshToken as String?,
      );
      if (session.passengerId.isEmpty) {
        throw const FormatException('Missing id.');
      }
      return session;
    } on Exception {
      _throw(PassengerAuthFailure.invalidResponse);
    }
  }

  PassengerSession _parseSessionResponse(
    List<int> bodyBytes,
    PassengerStoredCredentials credentials,
  ) {
    try {
      final decoded = _decodeObject(bodyBytes);
      if (decoded['authenticated'] != true) {
        throw const FormatException('Session is not authenticated.');
      }
      return _parsePassenger(
        decoded['passenger'],
        token: credentials.accessToken,
        tokenType: credentials.tokenType,
        expiresInSeconds: _remainingSeconds(credentials),
        refreshToken: credentials.refreshToken,
      );
    } on Exception {
      _throw(PassengerAuthFailure.invalidResponse);
    }
  }

  PassengerSession _parsePassenger(
    Object? value, {
    required String token,
    required String tokenType,
    int? expiresInSeconds,
    String? refreshToken,
  }) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Passenger identity is missing.');
    }
    final rawId = value['id'];
    final rawUsername = value['username'];
    final rawAuthMethod = value['authMethod'];
    final id = switch (rawId) {
      int number when number > 0 => number.toString(),
      String text when text.trim().isNotEmpty => text.trim(),
      _ => null,
    };
    if (id == null ||
        (rawUsername != null && rawUsername is! String) ||
        (rawAuthMethod != null && rawAuthMethod is! String)) {
      throw const FormatException('Passenger identity is invalid.');
    }
    return PassengerSession(
      passengerId: id,
      username: rawUsername as String?,
      authMethod: rawAuthMethod as String?,
      accessToken: token,
      refreshToken: refreshToken,
      tokenType: tokenType,
      expiresInSeconds: expiresInSeconds,
    );
  }

  Map<String, dynamic> _decodeObject(List<int> bodyBytes) {
    final decoded = jsonDecode(utf8.decode(bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backend response must be a JSON object.');
    }
    return decoded;
  }

  Future<PassengerStoredCredentials?> _readCredentials() async {
    try {
      return await tokenStorage.readCredentials();
    } on Exception {
      _throw(PassengerAuthFailure.secureStorage);
    }
  }

  Future<void> _writeCredentials(PassengerStoredCredentials credentials) async {
    try {
      await tokenStorage.writeCredentials(credentials);
    } on Exception {
      _throw(PassengerAuthFailure.secureStorage);
    }
  }

  Future<void> _clearCredentials() async {
    try {
      await tokenStorage.deleteCredentials();
    } on Exception {
      _throw(PassengerAuthFailure.secureStorage);
    }
    _credentials = null;
    currentSession = null;
  }

  Future<void> _persistSession(PassengerSession session) async {
    final credentials = PassengerStoredCredentials(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      passengerId: session.passengerId,
      username: session.username,
      tokenType: session.tokenType,
      accessTokenExpiresAtEpochMs: _expiryEpochMs(session.expiresInSeconds),
    );
    await _writeCredentials(credentials);
    _credentials = credentials;
    currentSession = session;
  }

  int? _expiryEpochMs(int? expiresInSeconds) => expiresInSeconds == null
      ? null
      : _now()
            .toUtc()
            .add(Duration(seconds: expiresInSeconds))
            .millisecondsSinceEpoch;

  int? _remainingSeconds(PassengerStoredCredentials credentials) {
    final expiry = credentials.accessTokenExpiresAt;
    if (expiry == null) return null;
    return expiry.difference(_now().toUtc()).inSeconds.clamp(0, 1 << 31);
  }

  int? _jwtExpiryEpochMs(String token) {
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(token.split('.')[1])),
      );
      final decoded = jsonDecode(payload);
      final exp = decoded is Map<String, dynamic> ? decoded['exp'] : null;
      return exp is int ? exp * 1000 : null;
    } on Object {
      return null;
    }
  }

  static String? normalizeInternationalPhone(String input) {
    final compact = input.trim().replaceAll(RegExp(r'[\s().-]'), '');
    final normalized = compact.startsWith('00')
        ? '+${compact.substring(2)}'
        : compact;
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(normalized)) return null;
    return normalized;
  }

  Never _throw(PassengerAuthFailure failure) {
    throw PassengerAuthException(failure);
  }
}
