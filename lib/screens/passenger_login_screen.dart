import 'package:flutter/material.dart';

import '../localization/translations.dart';
import '../models/passenger_session.dart';
import '../services/passenger_auth_service.dart';

class PassengerLoginScreen extends StatefulWidget {
  final PassengerAuthService authService;
  final Future<void> Function(PassengerSession session) onAuthenticated;
  final String? sessionCheckMessage;
  final Future<void> Function()? onRetrySessionCheck;

  const PassengerLoginScreen({
    super.key,
    required this.authService,
    required this.onAuthenticated,
    this.sessionCheckMessage,
    this.onRetrySessionCheck,
  });

  @override
  State<PassengerLoginScreen> createState() => _PassengerLoginScreenState();
}

class _PassengerLoginScreenState extends State<PassengerLoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isSigningIn = false;
  bool _isRetryingSession = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_isSigningIn) {
      return;
    }
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });

    try {
      final session = await widget.authService.login(
        username: _usernameController.text,
        password: _passwordController.text,
      );
      await widget.onAuthenticated(session);
    } on PassengerAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _messageFor(error.failure);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = AppTranslations.passengerLoginUnexpectedError;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
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

  String _messageFor(PassengerAuthFailure failure) {
    return switch (failure) {
      PassengerAuthFailure.invalidCredentials =>
        AppTranslations.passengerLoginInvalidCredentials,
      PassengerAuthFailure.networkUnavailable =>
        AppTranslations.passengerLoginNetworkError,
      PassengerAuthFailure.backendUnavailable =>
        AppTranslations.passengerLoginBackendError,
      PassengerAuthFailure.secureStorage =>
        AppTranslations.passengerLoginStorageError,
      PassengerAuthFailure.invalidResponse =>
        AppTranslations.passengerLoginUnexpectedError,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/City6_registration_screen_background.png',
            fit: BoxFit.cover,
          ),
          Container(color: const Color(0x99081A2B)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
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
                        AppTranslations.passengerLoginTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _usernameController,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        enableSuggestions: false,
                        textCapitalization: TextCapitalization.none,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                        ),
                        decoration: _inputDecoration(
                          label: AppTranslations.passengerUsername,
                          icon: Icons.person_outline,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _signIn(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                        ),
                        decoration:
                            _inputDecoration(
                              label: AppTranslations.passengerPassword,
                              icon: Icons.lock_outline,
                            ).copyWith(
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: Colors.white.withValues(alpha: 0.70),
                                ),
                              ),
                            ),
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
                          onPressed: _isSigningIn ? null : _signIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1768A8),
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isSigningIn
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  AppTranslations.passengerLoginButton,
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

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
      prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.75)),
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
  }
}
