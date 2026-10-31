import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../localization/translations.dart';

class SmsVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const SmsVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<SmsVerificationScreen> createState() => _SmsVerificationScreenState();
}

class _SmsVerificationScreenState extends State<SmsVerificationScreen> {
  final TextEditingController _codeController = TextEditingController();

  Future<void> _verifyCode() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppTranslations.smsRegistrationNotAvailable)),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A2942),
        foregroundColor: Colors.white,
        title: const Text('Потвърждение'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              const Icon(
                Icons.sms_outlined,
                size: 64,
                color: Color(0xFF1768A8),
              ),

              const SizedBox(height: 24),

              const Text(
                'Въведете SMS кода',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              Text(
                'Изпратихме код на\n${widget.phoneNumber}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 32),

              TextField(
                controller: _codeController,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 12,
                ),
                decoration: InputDecoration(
                  hintText: '------',
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _verifyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1768A8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'ПОТВЪРДИ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'SMS регистрацията ще бъде активирана за публичната версия.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black45, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
