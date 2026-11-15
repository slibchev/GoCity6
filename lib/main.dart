import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'config/colors.dart';
import 'localization/app_language.dart';
import 'localization/translations.dart';
import 'models/passenger_session.dart';
import 'screens/city6_intro_screen.dart';
import 'screens/language_screen.dart';
import 'screens/passenger_login_screen.dart';
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

class _TaxiAppState extends State<TaxiApp> {
  late final PassengerAuthService _authService;
  late final RideRequestService _rideRequestService;
  late final Future<SharedPreferences> _preferencesFuture;
  SharedPreferences? _preferences;

  PassengerSession? _session;
  PassengerAuthException? _sessionRestoreError;
  bool _isCheckingSession = true;
  bool _needsLanguageSelection = false;
  final LanguageSaveQueue _languageSaveQueue = LanguageSaveQueue();

  bool _hasKnownLanguage(String? value) =>
      value == 'english' || value == 'bulgarian';

  AppLanguage _parseLanguage(String? value) =>
      value == 'english' ? AppLanguage.english : AppLanguage.bulgarian;

  String _languagePreferenceValue(AppLanguage language) =>
      language == AppLanguage.english ? 'english' : 'bulgarian';

  @override
  void initState() {
    super.initState();
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
    setState(() {
      _session = session;
      _sessionRestoreError = null;
      _needsLanguageSelection = false;
    });
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) return;
    setState(() {
      _session = null;
      _sessionRestoreError = null;
    });
  }

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
      home: _isCheckingSession
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : session == null
          ? _needsLanguageSelection
                ? LanguageScreen(onLanguageSelected: _saveLanguage)
                : PassengerLoginScreen(
                    authService: _authService,
                    onAuthenticated: _onAuthenticated,
                    onLanguageSelected: _saveLanguage,
                    sessionCheckMessage: _sessionErrorMessage,
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
