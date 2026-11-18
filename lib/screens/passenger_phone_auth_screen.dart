import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_language.dart';
import '../localization/translations.dart';
import '../models/passenger_session.dart';
import '../services/passenger_auth_service.dart';
import '../widgets/language_selector.dart';

class PassengerPhoneAuthScreen extends StatefulWidget {
  final PassengerAuthService authService;
  final Future<void> Function(PassengerSession session) onAuthenticated;
  final SaveAppLanguage? onLanguageSelected;
  final String? sessionCheckMessage;
  final String? noticeMessage;
  final Future<void> Function()? onRetrySessionCheck;

  const PassengerPhoneAuthScreen({
    super.key,
    required this.authService,
    required this.onAuthenticated,
    this.onLanguageSelected,
    this.sessionCheckMessage,
    this.noticeMessage,
    this.onRetrySessionCheck,
  });

  @override
  State<PassengerPhoneAuthScreen> createState() =>
      _PassengerPhoneAuthScreenState();
}

class _PassengerPhoneAuthScreenState extends State<PassengerPhoneAuthScreen>
    with AppLanguageAwareState<PassengerPhoneAuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isSending = false;
  bool _isRetryingSession = false;
  PassengerAuthFailure? _errorFailure;

  String? get _errorMessage =>
      _errorFailure == null ? null : _messageFor(_errorFailure!);

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_isSending || widget.sessionCheckMessage != null) return;
    setState(() {
      _isSending = true;
      _errorFailure = null;
    });
    try {
      final challenge = await widget.authService.startPhoneVerification(
        _phoneController.text,
      );
      if (!mounted) return;
      final session = await Navigator.of(context).push<PassengerSession>(
        MaterialPageRoute(
          builder: (_) => PassengerSmsVerificationScreen(
            authService: widget.authService,
            challenge: challenge,
            onLanguageSelected: widget.onLanguageSelected,
          ),
        ),
      );
      if (session != null && mounted) {
        await widget.onAuthenticated(session);
      }
    } on PassengerAuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorFailure = error.failure);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorFailure = PassengerAuthFailure.invalidResponse);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _retrySessionCheck() async {
    final retry = widget.onRetrySessionCheck;
    if (retry == null || _isRetryingSession) return;
    setState(() => _isRetryingSession = true);
    try {
      await retry();
    } finally {
      if (mounted) setState(() => _isRetryingSession = false);
    }
  }

  Future<bool> _changeLanguage(AppLanguage language) async {
    final save = widget.onLanguageSelected;
    if (save == null) return false;
    final saved = await save(language);
    if (mounted && saved) setState(() => _errorFailure = null);
    return saved;
  }

  String _messageFor(PassengerAuthFailure failure) => switch (failure) {
    PassengerAuthFailure.invalidPhone => AppTranslations.passengerPhoneInvalid,
    PassengerAuthFailure.rateLimited => AppTranslations.passengerRateLimited,
    PassengerAuthFailure.networkUnavailable =>
      AppTranslations.passengerLoginNetworkError,
    PassengerAuthFailure.backendUnavailable =>
      AppTranslations.passengerLoginBackendError,
    PassengerAuthFailure.secureStorage =>
      AppTranslations.passengerLoginStorageError,
    PassengerAuthFailure.invalidCredentials =>
      AppTranslations.passengerLoginInvalidCredentials,
    PassengerAuthFailure.invalidCode => AppTranslations.passengerCodeInvalid,
    PassengerAuthFailure.challengeExpired =>
      AppTranslations.passengerChallengeExpired,
    PassengerAuthFailure.sessionExpired =>
      AppTranslations.passengerSessionExpired,
    PassengerAuthFailure.invalidResponse =>
      AppTranslations.passengerLoginUnexpectedError,
  };

  InputDecoration _inputDecoration() => InputDecoration(
    labelText: AppTranslations.passengerPhoneLabel,
    hintText: AppTranslations.passengerPhoneHint,
    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.48)),
    prefixIcon: Icon(
      Icons.phone_outlined,
      color: Colors.white.withValues(alpha: 0.75),
    ),
    filled: true,
    fillColor: Colors.black.withValues(alpha: 0.25),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFF5CAEFF), width: 1.5),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: true,
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/City6_registration_screen_background.png',
          fit: BoxFit.cover,
        ),
        Container(color: const Color(0x99081A2B)),
        if (widget.onLanguageSelected != null)
          Positioned(
            top: 8,
            right: 12,
            child: SafeArea(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x9907192A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: LanguageSelectorButton(
                  onLanguageSelected: _changeLanguage,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xCC07192A),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.30),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppTranslations.passengerPhoneTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppTranslations.passengerPhoneDescription,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _sendCode(),
                      autocorrect: false,
                      enableSuggestions: false,
                      style: const TextStyle(color: Colors.white, fontSize: 17),
                      decoration: _inputDecoration(),
                    ),
                    if (widget.sessionCheckMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        widget.sessionCheckMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      TextButton(
                        onPressed: _isRetryingSession
                            ? null
                            : _retrySessionCheck,
                        child: Text(
                          _isRetryingSession
                              ? AppTranslations.processing
                              : AppTranslations.retrySessionCheck,
                          style: const TextStyle(color: Color(0xFF9ACBFF)),
                        ),
                      ),
                    ],
                    if (widget.noticeMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        widget.noticeMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFFFD27A)),
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFFFB4AB)),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed:
                            _isSending || widget.sessionCheckMessage != null
                            ? null
                            : _sendCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1768A8),
                          foregroundColor: Colors.white,
                          elevation: 8,
                          shadowColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isSending
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                AppTranslations.passengerSendCode,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class PassengerSmsVerificationScreen extends StatefulWidget {
  final PassengerAuthService authService;
  final PassengerPhoneChallenge challenge;
  final SaveAppLanguage? onLanguageSelected;

  const PassengerSmsVerificationScreen({
    super.key,
    required this.authService,
    required this.challenge,
    this.onLanguageSelected,
  });

  @override
  State<PassengerSmsVerificationScreen> createState() =>
      _PassengerSmsVerificationScreenState();
}

class _PassengerSmsVerificationScreenState
    extends State<PassengerSmsVerificationScreen>
    with AppLanguageAwareState<PassengerSmsVerificationScreen> {
  final TextEditingController _codeController = TextEditingController();
  late PassengerPhoneChallenge _challenge;
  late DateTime _expiresAt;
  late DateTime _resendAt;
  Timer? _countdownTimer;
  bool _isVerifying = false;
  bool _isResending = false;
  bool _verificationRateLimited = false;
  bool _resendRateLimited = false;
  PassengerAuthFailure? _errorFailure;

  String? get _errorMessage =>
      _errorFailure == null ? null : _messageFor(_errorFailure!);
  int _secondsToExpiry = 0;
  int _secondsToResend = 0;

  @override
  void initState() {
    super.initState();
    _challenge = widget.challenge;
    final now = DateTime.now();
    _expiresAt = now.add(Duration(seconds: _challenge.expiresInSeconds));
    _resendAt = now.add(Duration(seconds: _challenge.resendAfterSeconds));
    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(_updateCountdown);
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  bool get _isExpired => _secondsToExpiry <= 0;

  void _updateCountdown() {
    final now = DateTime.now();
    _secondsToExpiry = _expiresAt.difference(now).inSeconds.clamp(0, 1 << 30);
    _secondsToResend = _resendAt.difference(now).inSeconds.clamp(0, 1 << 30);
  }

  Future<void> _verify() async {
    if (_isVerifying ||
        _verificationRateLimited ||
        _isExpired ||
        _codeController.text.length != 6) {
      return;
    }
    setState(() {
      _isVerifying = true;
      _errorFailure = null;
    });
    try {
      final session = await widget.authService.verifyPhoneCode(
        challenge: _challenge,
        code: _codeController.text,
      );
      if (mounted) Navigator.of(context).pop(session);
    } on PassengerAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorFailure = error.failure;
        if (error.failure == PassengerAuthFailure.rateLimited) {
          _verificationRateLimited = true;
        }
        if (error.failure == PassengerAuthFailure.challengeExpired) {
          _secondsToExpiry = 0;
        }
        if (error.failure == PassengerAuthFailure.invalidCode) {
          _codeController.clear();
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _errorFailure = PassengerAuthFailure.invalidResponse);
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    if (_isResending ||
        _isVerifying ||
        _resendRateLimited ||
        _isExpired ||
        _secondsToResend > 0 ||
        _challenge.resendsRemaining <= 0) {
      return;
    }
    setState(() {
      _isResending = true;
      _errorFailure = null;
    });
    try {
      final updated = await widget.authService.resendPhoneVerification(
        _challenge,
      );
      if (!mounted) return;
      setState(() {
        _challenge = updated;
        _expiresAt = DateTime.now().add(
          Duration(seconds: updated.expiresInSeconds),
        );
        _resendAt = DateTime.now().add(
          Duration(seconds: updated.resendAfterSeconds),
        );
        _updateCountdown();
      });
    } on PassengerAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorFailure = error.failure;
        if (error.failure == PassengerAuthFailure.rateLimited) {
          _resendRateLimited = true;
        }
        if (error.failure == PassengerAuthFailure.challengeExpired) {
          _secondsToExpiry = 0;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _errorFailure = PassengerAuthFailure.invalidResponse);
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  String _messageFor(PassengerAuthFailure failure) => switch (failure) {
    PassengerAuthFailure.invalidPhone => AppTranslations.passengerPhoneInvalid,
    PassengerAuthFailure.invalidCode => AppTranslations.passengerCodeInvalid,
    PassengerAuthFailure.challengeExpired =>
      AppTranslations.passengerChallengeExpired,
    PassengerAuthFailure.rateLimited => AppTranslations.passengerRateLimited,
    PassengerAuthFailure.networkUnavailable =>
      AppTranslations.passengerLoginNetworkError,
    PassengerAuthFailure.backendUnavailable =>
      AppTranslations.passengerLoginBackendError,
    PassengerAuthFailure.secureStorage =>
      AppTranslations.passengerLoginStorageError,
    PassengerAuthFailure.sessionExpired =>
      AppTranslations.passengerSessionExpired,
    PassengerAuthFailure.invalidCredentials ||
    PassengerAuthFailure.invalidResponse =>
      AppTranslations.passengerLoginUnexpectedError,
  };

  Future<bool> _changeLanguage(AppLanguage language) async {
    final save = widget.onLanguageSelected;
    if (save == null) return false;
    return save(language);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF1F3F5),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0A2942),
      foregroundColor: Colors.white,
      title: Text(AppTranslations.passengerCodeTitle),
      centerTitle: true,
      leading: IconButton(
        tooltip: AppTranslations.passengerChangePhone,
        onPressed: _isVerifying ? null : () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back),
      ),
      actions: [
        if (widget.onLanguageSelected != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: LanguageSelectorButton(
              onLanguageSelected: _changeLanguage,
              foregroundColor: Colors.white,
            ),
          ),
      ],
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.sms_outlined, size: 64, color: Color(0xFF1768A8)),
            const SizedBox(height: 24),
            Text(
              AppTranslations.passengerCodeTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '${AppTranslations.passengerCodeSentTo}\n${_challenge.maskedPhone}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppTranslations.passengerCodeExpires(_secondsToExpiry),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            if (_isExpired) ...[
              const SizedBox(height: 8),
              Text(
                AppTranslations.passengerChallengeExpired,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 24),
            TextField(
              controller: _codeController,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _verify(),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 12,
              ),
              decoration: InputDecoration(
                labelText: AppTranslations.passengerCodeLabel,
                hintText: '------',
                counterText: '',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            if (_errorMessage != null &&
                !(_isExpired &&
                    _errorFailure ==
                        PassengerAuthFailure.challengeExpired)) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed:
                    _isVerifying ||
                        _verificationRateLimited ||
                        _isExpired ||
                        _codeController.text.length != 6
                    ? null
                    : _verify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1768A8),
                  foregroundColor: Colors.white,
                ),
                child: _isVerifying
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(AppTranslations.passengerVerifyCode),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _challenge.resendsRemaining <= 0
                  ? AppTranslations.passengerRateLimited
                  : _secondsToResend > 0
                  ? AppTranslations.passengerResendCountdown(_secondsToResend)
                  : AppTranslations.passengerResendCode,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            if (!_isExpired && _challenge.resendsRemaining > 0)
              TextButton(
                onPressed:
                    _isResending ||
                        _resendRateLimited ||
                        _isVerifying ||
                        _secondsToResend > 0
                    ? null
                    : _resend,
                child: Text(
                  _isResending
                      ? AppTranslations.processing
                      : AppTranslations.passengerResendCode,
                ),
              ),
            if (!_isExpired && _challenge.resendsRemaining > 0)
              Text(
                AppTranslations.passengerResendMayRepeatCode,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black45, fontSize: 12),
              ),
            if (_isExpired)
              TextButton(
                onPressed: _isVerifying
                    ? null
                    : () => Navigator.of(context).pop(),
                child: Text(AppTranslations.passengerChangePhone),
              ),
          ],
        ),
      ),
    ),
  );
}
