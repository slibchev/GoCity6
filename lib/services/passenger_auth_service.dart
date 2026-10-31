import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import '../models/passenger_session.dart';

enum PassengerAuthFailure {
  invalidCredentials,
  networkUnavailable,
  backendUnavailable,
  invalidResponse,
  secureStorage,
}

class PassengerAuthException implements Exception {
  final PassengerAuthFailure failure;

  const PassengerAuthException(this.failure);
}

abstract interface class PassengerTokenStorage {
  Future<String?> readToken();
  Future<void> writeToken(String token);
  Future<void> deleteToken();
}

class FlutterSecurePassengerTokenStorage implements PassengerTokenStorage {
  static const String _tokenKey = 'city6.passenger.accessToken';

  final FlutterSecureStorage storage;

  const FlutterSecurePassengerTokenStorage({
    this.storage = const FlutterSecureStorage(),
  });

  @override
  Future<String?> readToken() => storage.read(key: _tokenKey);

  @override
  Future<void> writeToken(String token) =>
      storage.write(key: _tokenKey, value: token);

  @override
  Future<void> deleteToken() => storage.delete(key: _tokenKey);
}

class PassengerAuthService {
  final String? baseUrl;
  final http.Client client;
  final PassengerTokenStorage tokenStorage;
  final Duration requestTimeout;

  String? _accessToken;
  PassengerSession? currentSession;

  PassengerAuthService({
    this.baseUrl,
    http.Client? client,
    PassengerTokenStorage? tokenStorage,
    this.requestTimeout = const Duration(seconds: 10),
  }) : client = client ?? http.Client(),
       tokenStorage =
           tokenStorage ?? const FlutterSecurePassengerTokenStorage();

  String get _baseUrl => baseUrl ?? BackendConfig.baseUrl;

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

    late final http.Response response;
    try {
      response = await client
          .post(
            Uri.parse('$_baseUrl/passenger/login'),
            headers: const {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'username': normalizedUsername,
              'password': password,
            }),
          )
          .timeout(requestTimeout);
    } on TimeoutException {
      throw const PassengerAuthException(
        PassengerAuthFailure.networkUnavailable,
      );
    } on http.ClientException {
      throw const PassengerAuthException(
        PassengerAuthFailure.networkUnavailable,
      );
    } on Exception {
      throw const PassengerAuthException(
        PassengerAuthFailure.networkUnavailable,
      );
    }

    if (response.statusCode == 401) {
      throw const PassengerAuthException(
        PassengerAuthFailure.invalidCredentials,
      );
    }
    if (response.statusCode == 408 ||
        response.statusCode == 429 ||
        response.statusCode >= 500) {
      throw const PassengerAuthException(
        PassengerAuthFailure.backendUnavailable,
      );
    }
    if (response.statusCode != 200) {
      throw const PassengerAuthException(PassengerAuthFailure.invalidResponse);
    }

    final session = _parseLoginResponse(response.bodyBytes);
    try {
      await tokenStorage.writeToken(session.accessToken);
    } on Exception {
      throw const PassengerAuthException(PassengerAuthFailure.secureStorage);
    }

    _accessToken = session.accessToken;
    currentSession = session;
    return session;
  }

  Future<PassengerSession?> restoreSession() async {
    late final String? token;
    try {
      token = await tokenStorage.readToken();
    } on Exception {
      throw const PassengerAuthException(PassengerAuthFailure.secureStorage);
    }

    if (token == null || token.trim().isEmpty) {
      _accessToken = null;
      currentSession = null;
      return null;
    }

    _accessToken = token;
    late final http.Response response;
    try {
      response = await client
          .get(
            Uri.parse('$_baseUrl/passenger/session'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(requestTimeout);
    } on TimeoutException {
      throw const PassengerAuthException(
        PassengerAuthFailure.networkUnavailable,
      );
    } on http.ClientException {
      throw const PassengerAuthException(
        PassengerAuthFailure.networkUnavailable,
      );
    } on Exception {
      throw const PassengerAuthException(
        PassengerAuthFailure.networkUnavailable,
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      try {
        await tokenStorage.deleteToken();
      } on Exception {
        throw const PassengerAuthException(PassengerAuthFailure.secureStorage);
      }
      _accessToken = null;
      currentSession = null;
      return null;
    }
    if (response.statusCode == 408 ||
        response.statusCode == 429 ||
        response.statusCode >= 500) {
      throw const PassengerAuthException(
        PassengerAuthFailure.backendUnavailable,
      );
    }
    if (response.statusCode != 200) {
      throw const PassengerAuthException(PassengerAuthFailure.invalidResponse);
    }

    final session = _parseSessionResponse(response.bodyBytes, token);
    currentSession = session;
    return session;
  }

  Future<String?> authorizationHeader() async {
    final token = _accessToken ?? await tokenStorage.readToken();
    if (token == null || token.trim().isEmpty) {
      return null;
    }
    return 'Bearer $token';
  }

  Future<void> logout() async {
    try {
      await tokenStorage.deleteToken();
    } on Exception {
      throw const PassengerAuthException(PassengerAuthFailure.secureStorage);
    }
    _accessToken = null;
    currentSession = null;
  }

  PassengerSession _parseLoginResponse(List<int> bodyBytes) {
    try {
      final decoded = _decodeObject(bodyBytes);
      final token = decoded['token'];
      final tokenType = decoded['tokenType'];
      final expiresInSeconds = decoded['expiresInSeconds'];
      if (token is! String ||
          token.trim().isEmpty ||
          tokenType is! String ||
          tokenType.toLowerCase() != 'bearer' ||
          expiresInSeconds is! int ||
          expiresInSeconds <= 0) {
        throw const FormatException('Invalid login response.');
      }
      return _parsePassenger(
        decoded['passenger'],
        token: token,
        tokenType: tokenType,
        expiresInSeconds: expiresInSeconds,
      );
    } on Exception {
      throw const PassengerAuthException(PassengerAuthFailure.invalidResponse);
    }
  }

  PassengerSession _parseSessionResponse(List<int> bodyBytes, String token) {
    try {
      final decoded = _decodeObject(bodyBytes);
      if (decoded['authenticated'] != true) {
        throw const FormatException('Session is not authenticated.');
      }
      return _parsePassenger(
        decoded['passenger'],
        token: token,
        tokenType: 'Bearer',
      );
    } on Exception {
      throw const PassengerAuthException(PassengerAuthFailure.invalidResponse);
    }
  }

  PassengerSession _parsePassenger(
    Object? value, {
    required String token,
    required String tokenType,
    int? expiresInSeconds,
  }) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Passenger identity is missing.');
    }
    final rawId = value['id'];
    final username = value['username'];
    final id = switch (rawId) {
      int number when number > 0 => number.toString(),
      String text when text.trim().isNotEmpty => text.trim(),
      _ => null,
    };
    if (id == null || username is! String || username.trim().isEmpty) {
      throw const FormatException('Passenger identity is invalid.');
    }
    return PassengerSession(
      passengerId: id,
      username: username,
      accessToken: token,
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
}
