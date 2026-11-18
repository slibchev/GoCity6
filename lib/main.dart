import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'config/backend_config.dart';
import 'config/colors.dart';
import 'localization/app_language.dart';
import 'localization/translations.dart';
import 'models/passenger_session.dart';
import 'screens/city6_intro_screen.dart';
import 'screens/language_screen.dart';
import 'screens/passenger_phone_auth_screen.dart';
import 'services/active_ride_store.dart';
import 'services/backend_ride_request_service.dart';
import 'services/passenger_auth_service.dart';
import 'services/ride_request_service.dart';
import 'widgets/language_selector.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();
  final savedLanguage = preferences.getString('language');

  if (savedLanguage == 'english') {
    AppTranslations.currentLanguage = AppLanguage.english;
  } else {
    AppTranslations.currentLanguage = AppLanguage.bulgarian;
  }

  runApp(
    TaxiApp(preferences: preferences, authService: PassengerAuthService()),
  );
}

class TaxiApp extends StatefulWidget {
  final PassengerAuthService? authService;
  final SharedPreferences? preferences;
  final RideRequestService? rideRequestService;
  final bool skipIntroAnimation;

  const TaxiApp({
    super.key,
    this.authService,
    this.preferences,
    this.rideRequestService,
    this.skipIntroAnimation = false,
  });

  @override
  State<TaxiApp> createState() => _TaxiAppState();
}

class _TaxiAppState extends State<TaxiApp> with WidgetsBindingObserver {
  late final PassengerAuthService _authService;
  late final RideRequestService _rideRequestService;
  late final Future<SharedPreferences> _preferencesFuture;
  SharedPreferences? _preferences;

  PassengerSession? _session;
  PassengerAuthException? _sessionRestoreError;
  bool _isCheckingSession = true;
  bool _needsLanguageSelection = false;
  final LanguageSaveQueue _languageSaveQueue = LanguageSaveQueue();
  bool _isLifecycleForeground = true;
  bool _foregroundEventSent = false;
  bool _logoutNeedsNotice = false;
  DateTime? _lastInteractionActivityAt;

  bool _hasKnownLanguage(String? value) =>
      value == 'english' || value == 'bulgarian';

  AppLanguage _parseLanguage(String? value) =>
      value == 'english' ? AppLanguage.english : AppLanguage.bulgarian;

  String _languagePreferenceValue(AppLanguage language) =>
      language == AppLanguage.english ? 'english' : 'bulgarian';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isLifecycleForeground =
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.detached;
    _authService = widget.authService ?? PassengerAuthService();
    _preferences = widget.preferences;
    _preferencesFuture = widget.preferences == null
        ? SharedPreferences.getInstance()
        : Future<SharedPreferences>.value(widget.preferences);
    _rideRequestService =
        widget.rideRequestService ??
        BackendRideRequestService(
          authorizationHeaderProvider: _authService.authorizationHeader,
        );
    _restoreSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _isLifecycleForeground = false;
      _foregroundEventSent = false;
      return;
    }
    if (state == AppLifecycleState.resumed) {
      final wasForeground = _isLifecycleForeground;
      _isLifecycleForeground = true;
      if (!wasForeground) _recordForegroundActivity();
    }
  }

  void _recordForegroundActivity() {
    if (_session == null || !_isLifecycleForeground || _foregroundEventSent) {
      return;
    }
    _foregroundEventSent = true;
    unawaited(_recordActivitySafely('foreground'));
  }

  void _recordInteractionActivity() {
    if (_session == null) return;
    final now = DateTime.now();
    final last = _lastInteractionActivityAt;
    if (last != null && now.difference(last) < const Duration(seconds: 30)) {
      return;
    }
    _lastInteractionActivityAt = now;
    unawaited(_recordActivitySafely('interaction'));
  }

  Future<void> _recordActivitySafely(String activityType) async {
    try {
      await _authService.recordActivity(activityType);
    } catch (_) {
      // Activity reports are best-effort and never block ride interactions.
    }
  }

  Future<void> _restoreSession() async {
    if (mounted) {
      setState(() {
        _isCheckingSession = true;
      });
    }

    try {
      final preferences = await _preferencesFuture;
      _preferences = preferences;
      final savedLanguage = preferences.getString('language');
      AppTranslations.currentLanguage = _parseLanguage(savedLanguage);

      final restoredSession = await _authService.restoreSession();
      if (!mounted) return;

      if (restoredSession != null && !_hasKnownLanguage(savedLanguage)) {
        try {
          await preferences.setString('language', 'bulgarian');
        } catch (_) {
          // Existing authenticated installs keep the safe Bulgarian default.
        }
      }
      if (!mounted) return;

      setState(() {
        _session = restoredSession;
        _sessionRestoreError = null;
        _needsLanguageSelection =
            restoredSession == null && !_hasKnownLanguage(savedLanguage);
        _isCheckingSession = false;
      });
      if (restoredSession != null) _recordForegroundActivity();
    } on PassengerAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _session = null;
        _sessionRestoreError = error;
        _needsLanguageSelection = false;
        _isCheckingSession = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _session = null;
        _sessionRestoreError = const PassengerAuthException(
          PassengerAuthFailure.invalidResponse,
        );
        _needsLanguageSelection = false;
        _isCheckingSession = false;
      });
    }
  }

  Future<bool> _saveLanguage(AppLanguage language) =>
      _languageSaveQueue.run(() => _persistLanguage(language));

  Future<bool> _persistLanguage(AppLanguage language) async {
    try {
      final preferences = await _preferencesFuture;
      final saved = await preferences.setString(
        'language',
        _languagePreferenceValue(language),
      );
      if (!saved) return false;

      AppTranslations.currentLanguage = language;
      if (mounted) {
        setState(() {
          if (_session == null && _sessionRestoreError == null) {
            _needsLanguageSelection = false;
          }
        });
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _onAuthenticated(PassengerSession session) async {
    if (!mounted) return;
    _foregroundEventSent = false;
    _lastInteractionActivityAt = null;
    setState(() {
      _session = session;
      _sessionRestoreError = null;
      _needsLanguageSelection = false;
      _logoutNeedsNotice = false;
    });
    _recordForegroundActivity();
  }

  Future<void> _logout() async {
    final serverRevoked = await _authService.logout();
    if (!mounted) return;
    setState(() {
      _session = null;
      _sessionRestoreError = null;
      _logoutNeedsNotice = !serverRevoked;
    });
    _foregroundEventSent = false;
    _lastInteractionActivityAt = null;
  }

  String? get _logoutNotice => _logoutNeedsNotice
      ? AppTranslations.passengerLogoutServerUnavailable
      : null;

  String? get _sessionErrorMessage {
    final error = _sessionRestoreError;
    if (error == null) return null;
    if (error.failure == PassengerAuthFailure.secureStorage) {
      return AppTranslations.passengerLoginStorageError;
    }
    return AppTranslations.passengerSessionCheckError;
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
      ),
      builder: (context, child) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _recordInteractionActivity(),
        child: child ?? const SizedBox.shrink(),
      ),
      home: _isCheckingSession
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : session == null
          ? _needsLanguageSelection
                ? LanguageScreen(onLanguageSelected: _saveLanguage)
                : PassengerPhoneAuthScreen(
                    authService: _authService,
                    onAuthenticated: _onAuthenticated,
                    onLanguageSelected: _saveLanguage,
                    sessionCheckMessage: _sessionErrorMessage,
                    noticeMessage: _logoutNotice,
                    onRetrySessionCheck: _restoreSession,
                  )
          : FutureBuilder<SharedPreferences>(
              future: _preferencesFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Scaffold(
                    body: Center(child: Text('Could not open local storage.')),
                  );
                }
                if (!snapshot.hasData) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                _preferences ??= snapshot.data;
                return City6IntroScreen(
                  backgroundAsset: 'assets/images/city6_intro_background.png',
                  logoAsset: 'assets/images/city6_intro_logo.png',
                  activeRideStore: ActiveRideStore(
                    snapshot.data!,
                    passengerId: session.passengerId,
                    storageNamespace: BackendConfig.storageNamespace,
                  ),
                  rideRequestService: _rideRequestService,
                  passengerId: session.passengerId,
                  onLogout: _logout,
                  onLanguageSelected: _saveLanguage,
                  skipIntroAnimation: widget.skipIntroAnimation,
                );
              },
            ),
    );
  }
}
