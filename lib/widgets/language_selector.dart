import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_language.dart';
import '../localization/translations.dart';

typedef SaveAppLanguage = Future<bool> Function(AppLanguage language);

class LanguageSaveQueue {
  Future<void> _tail = Future<void>.value();

  Future<bool> run(Future<bool> Function() operation) {
    final result = Completer<bool>();
    _tail = _tail.then((_) async {
      try {
        result.complete(await operation());
      } catch (_) {
        result.complete(false);
      }
    });
    return result.future;
  }
}

mixin AppLanguageAwareState<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    AppTranslations.languageNotifier.addListener(_handleLanguageChanged);
  }

  void _handleLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppTranslations.languageNotifier.removeListener(_handleLanguageChanged);
    super.dispose();
  }
}

class LanguageSelectorButton extends StatefulWidget {
  final SaveAppLanguage onLanguageSelected;
  final Color? foregroundColor;

  const LanguageSelectorButton({
    super.key,
    required this.onLanguageSelected,
    this.foregroundColor,
  });

  @override
  State<LanguageSelectorButton> createState() => _LanguageSelectorButtonState();
}

class _LanguageSelectorButtonState extends State<LanguageSelectorButton> {
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
    final currentLanguage = AppTranslations.currentLanguage;

    return PopupMenuButton<AppLanguage>(
      tooltip: AppTranslations.chooseLanguage,
      onSelected: _isSaving ? null : _selectLanguage,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: AppLanguage.bulgarian,
          child: Text(AppTranslations.bulgarian),
        ),
        PopupMenuItem(
          value: AppLanguage.english,
          child: Text(AppTranslations.english),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          currentLanguage == AppLanguage.english ? 'БГ' : 'EN',
          style: TextStyle(
            color: widget.foregroundColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
