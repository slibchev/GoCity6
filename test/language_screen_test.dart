import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_app/localization/app_language.dart';
import 'package:taxi_app/localization/translations.dart';
import 'package:taxi_app/screens/language_screen.dart';
import 'package:taxi_app/widgets/language_selector.dart';

void main() {
  setUp(() {
    AppTranslations.currentLanguage = AppLanguage.bulgarian;
  });

  testWidgets('language screen offers Bulgarian and English choices', (
    tester,
  ) async {
    final selections = <AppLanguage>[];

    await tester.pumpWidget(
      MaterialApp(
        home: LanguageScreen(
          onLanguageSelected: (language) async {
            selections.add(language);
            return true;
          },
        ),
      ),
    );

    expect(find.text('Български'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pump();
    expect(selections, [AppLanguage.english]);

    await tester.tap(find.text('Български'));
    await tester.pump();
    expect(selections, [AppLanguage.english, AppLanguage.bulgarian]);
  });

  testWidgets('initial choice ignores double taps while saving', (
    tester,
  ) async {
    final saveCompleter = Completer<bool>();
    var saveCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: LanguageScreen(
          onLanguageSelected: (_) {
            saveCalls++;
            return saveCompleter.future;
          },
        ),
      ),
    );

    final englishButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'English'),
    );
    englishButton.onPressed!();
    englishButton.onPressed!();
    await tester.pump();

    expect(saveCalls, 1);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'English'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Български'),
          )
          .onPressed,
      isNull,
    );

    saveCompleter.complete(true);
    await tester.pumpAndSettle();
    expect(saveCalls, 1);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'English'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('language choices fit a narrow viewport without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: LanguageScreen(onLanguageSelected: (_) async => true)),
    );

    expect(find.text('English'), findsOneWidget);
    expect(find.text('Български'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await tester.ensureVisible(find.text('English'));
    expect(tester.getRect(find.text('English')).bottom, lessThanOrEqualTo(480));
    await tester.ensureVisible(find.text('Български'));
    expect(
      tester.getRect(find.text('Български')).bottom,
      lessThanOrEqualTo(480),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'shared selectors serialize rapid language changes in invocation order',
    (tester) async {
      final queue = LanguageSaveQueue();
      final firstWriteGate = Completer<void>();
      final started = <AppLanguage>[];
      final persisted = <AppLanguage>[];
      var activeWrites = 0;
      var maxActiveWrites = 0;

      Future<bool> saveLanguage(AppLanguage language) => queue.run(() async {
        started.add(language);
        activeWrites++;
        if (activeWrites > maxActiveWrites) {
          maxActiveWrites = activeWrites;
        }
        if (language == AppLanguage.english) {
          await firstWriteGate.future;
        }
        persisted.add(language);
        AppTranslations.currentLanguage = language;
        activeWrites--;
        return true;
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                LanguageSelectorButton(
                  key: const ValueKey('first-selector'),
                  onLanguageSelected: saveLanguage,
                ),
                LanguageSelectorButton(
                  key: const ValueKey('second-selector'),
                  onLanguageSelected: saveLanguage,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('first-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English').last);
      await tester.pump();
      expect(started, [AppLanguage.english]);

      await tester.tap(find.byKey(const ValueKey('second-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Български').last);
      await tester.pump();
      expect(started, [AppLanguage.english]);

      firstWriteGate.complete();
      await tester.pumpAndSettle();

      expect(started, [AppLanguage.english, AppLanguage.bulgarian]);
      expect(persisted, [AppLanguage.english, AppLanguage.bulgarian]);
      expect(maxActiveWrites, 1);
      expect(AppTranslations.currentLanguage, AppLanguage.bulgarian);
      expect(find.text('EN'), findsNWidgets(2));
    },
  );
}
