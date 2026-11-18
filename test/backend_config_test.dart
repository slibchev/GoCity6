import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_app/config/backend_config.dart';

void main() {
  const androidDefault = 'http://10.0.2.2:8080';

  test('normal mode preserves the Android backend and default namespace', () {
    final settings = BackendConfig.resolve(
      e2eMode: false,
      configuredBackendUrl: '',
      debugBuild: true,
      defaultBackendUrl: androidDefault,
    );

    expect(settings.baseUrl, androidDefault);
    expect(settings.storageNamespace, BackendConfig.defaultStorageNamespace);
  });

  test('explicit E2E mode selects only the isolated Android backend', () {
    final settings = BackendConfig.resolve(
      e2eMode: true,
      configuredBackendUrl: BackendConfig.e2eBackendUrl,
      debugBuild: true,
      defaultBackendUrl: androidDefault,
    );

    expect(settings.baseUrl, 'http://10.0.2.2:8082');
    expect(settings.storageNamespace, BackendConfig.e2eStorageNamespace);
  });

  test('E2E mode without an explicit URL refuses to resolve', () {
    expect(
      () => BackendConfig.resolve(
        e2eMode: true,
        configuredBackendUrl: '',
        debugBuild: true,
        defaultBackendUrl: androidDefault,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('wrong E2E URL refuses instead of falling back to port 8080', () {
    expect(
      () => BackendConfig.resolve(
        e2eMode: true,
        configuredBackendUrl: androidDefault,
        debugBuild: true,
        defaultBackendUrl: androidDefault,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('non-debug builds reject E2E mode and ignore an E2E URL by itself', () {
    expect(
      () => BackendConfig.resolve(
        e2eMode: true,
        configuredBackendUrl: BackendConfig.e2eBackendUrl,
        debugBuild: false,
        defaultBackendUrl: androidDefault,
      ),
      throwsA(isA<StateError>()),
    );

    final releaseSettings = BackendConfig.resolve(
      e2eMode: false,
      configuredBackendUrl: BackendConfig.e2eBackendUrl,
      debugBuild: false,
      defaultBackendUrl: androidDefault,
    );
    expect(releaseSettings.baseUrl, androidDefault);
    expect(
      releaseSettings.storageNamespace,
      BackendConfig.defaultStorageNamespace,
    );
  });

  test('platform defaults preserve the existing URL choices', () {
    expect(
      BackendConfig.defaultBackendUrlFor(
        isWeb: false,
        platform: TargetPlatform.android,
      ),
      androidDefault,
    );
    expect(
      BackendConfig.defaultBackendUrlFor(
        isWeb: false,
        platform: TargetPlatform.windows,
      ),
      'http://localhost:8080',
    );
    expect(
      BackendConfig.defaultBackendUrlFor(
        isWeb: true,
        platform: TargetPlatform.android,
      ),
      'http://localhost:8080',
    );
  });
}
