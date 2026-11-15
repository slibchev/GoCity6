import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../config/colors.dart';
import '../localization/app_language.dart';
import '../localization/translations.dart';

class LanguageScreen extends StatefulWidget {
  final Future<bool> Function(AppLanguage language) onLanguageSelected;

  const LanguageScreen({super.key, required this.onLanguageSelected});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  bool _isSaving = false;

  Future<void> _selectLanguage(AppLanguage language) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    var saved = false;
    try {
      saved = await widget.onLanguageSelected(language);
    } catch (_) {
      saved = false;
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.languageSaveError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, Color(0xFF183A63)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.airport_shuttle,
                      size: 100,
                      color: AppColors.secondary,
                    ),

                    const SizedBox(height: 25),

                    Text(
                      AppConfig.appName,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),

                    const SizedBox(height: 15),

                    Text(
                      AppTranslations.slogan,
                      style: const TextStyle(
                        fontSize: 20,
                        color: AppColors.secondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),

                    const SizedBox(height: 50),

                    Text(
                      AppTranslations.chooseLanguage,
                      style: const TextStyle(fontSize: 22, color: Colors.white),
                    ),

                    const SizedBox(height: 30),

                    ElevatedButton(
                      onPressed: _isSaving
                          ? null
                          : () => _selectLanguage(AppLanguage.english),
                      child: Text(
                        AppTranslations.english,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: _isSaving
                          ? null
                          : () => _selectLanguage(AppLanguage.bulgarian),
                      child: Text(
                        AppTranslations.bulgarian,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
