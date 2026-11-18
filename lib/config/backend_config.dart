import 'package:flutter/foundation.dart';

class BackendSettings {
  final String baseUrl;
  final String storageNamespace;

  const BackendSettings({
    required this.baseUrl,
    required this.storageNamespace,
  });
}

class BackendConfig {
  static const String e2eBackendUrl = 'http://10.0.2.2:8082';
  static const String defaultStorageNamespace = 'default';
  static const String e2eStorageNamespace = 'e2e';

  static const bool _e2eMode = bool.fromEnvironment(
    'CITY6_PASSENGER_E2E',
    defaultValue: false,
  );
  static const String _configuredBackendUrl = String.fromEnvironment(
    'CITY6_BACKEND_URL',
    defaultValue: '',
  );

  static String get baseUrl => current.baseUrl;

  /// Resolving this value also validates the compile-time E2E configuration.
  /// Secure Storage callers use it before reading credentials, so a bad E2E
  /// configuration can never fall through to the normal backend session.
  static String get storageNamespace => current.storageNamespace;

  static BackendSettings get current => resolve(
    e2eMode: _e2eMode,
    configuredBackendUrl: _configuredBackendUrl,
    debugBuild: kDebugMode,
    defaultBackendUrl: defaultBackendUrlFor(
      isWeb: kIsWeb,
      platform: defaultTargetPlatform,
    ),
  );

  static String defaultBackendUrlFor({
    required bool isWeb,
    required TargetPlatform platform,
  }) {
    if (!isWeb && platform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  @visibleForTesting
  static BackendSettings resolve({
    required bool e2eMode,
    required String configuredBackendUrl,
    required bool debugBuild,
    required String defaultBackendUrl,
  }) {
    if (!debugBuild) {
      if (e2eMode) {
        throw StateError('Passenger E2E mode is allowed only in debug builds.');
      }
      // Non-debug builds keep the historic backend even if a test URL define
      // was accidentally passed to the build command.
      return BackendSettings(
        baseUrl: defaultBackendUrl,
        storageNamespace: defaultStorageNamespace,
      );
    }

    if (!e2eMode) {
      return BackendSettings(
        baseUrl: defaultBackendUrl,
        storageNamespace: defaultStorageNamespace,
      );
    }

    if (configuredBackendUrl.trim() != e2eBackendUrl) {
      throw StateError(
        'Passenger E2E mode requires CITY6_BACKEND_URL=$e2eBackendUrl.',
      );
    }

    return const BackendSettings(
      baseUrl: e2eBackendUrl,
      storageNamespace: e2eStorageNamespace,
    );
  }
}
