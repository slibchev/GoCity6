import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_app/localization/app_language.dart';
import 'package:taxi_app/localization/translations.dart';
import 'package:taxi_app/models/favorite_place.dart';
import 'package:taxi_app/models/place_suggestion.dart';
import 'package:taxi_app/screens/favorites_screen.dart';
import 'package:taxi_app/services/backend_places_service.dart';
import 'package:taxi_app/services/favorites_service.dart';

class _MemoryFavoritesService extends FavoritesService {
  _MemoryFavoritesService([Iterable<FavoritePlace> initial = const []])
    : favorites = List.of(initial);

  final List<FavoritePlace> favorites;
  final List<FavoritePlace> added = [];
  final List<FavoritePlace> updated = [];
  final List<String> deleted = [];

  @override
  Future<List<FavoritePlace>> getFavorites() async => List.of(favorites);

  @override
  Future<void> addFavorite(FavoritePlace favorite) async {
    added.add(favorite);
    favorites.add(favorite);
  }

  @override
  Future<void> updateFavorite(FavoritePlace favorite) async {
    updated.add(favorite);
    final index = favorites.indexWhere((item) => item.id == favorite.id);
    if (index >= 0) favorites[index] = favorite;
  }

  @override
  Future<void> deleteFavorite(String id) async {
    deleted.add(id);
    favorites.removeWhere((favorite) => favorite.id == id);
  }
}

class _FakePlacesService extends BackendPlacesService {
  _FakePlacesService(this.suggestions);

  final List<PlaceSuggestion> suggestions;
  final List<String> queries = [];

  @override
  Future<List<PlaceSuggestion>> autocomplete({
    required String input,
    String? sessionToken,
  }) async {
    queries.add(input);
    return suggestions;
  }
}

const _favorite = FavoritePlace(
  id: 'home',
  name: 'My Home',
  address: 'Sofia Airport',
  placeId: 'sofia-airport',
);

void main() {
  tearDown(() {
    AppTranslations.currentLanguage = AppLanguage.bulgarian;
  });

  testWidgets('empty Favorites screen updates between Bulgarian and English', (
    tester,
  ) async {
    final service = _MemoryFavoritesService();
    await tester.pumpWidget(
      MaterialApp(home: FavoritesScreen(favoritesService: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Нямате любими адреси'), findsOneWidget);
    expect(
      find.text(
        'Добавете често използвани адреси като Дом, Работа или друг любим адрес.',
      ),
      findsOneWidget,
    );
    expect(find.text('Добави'), findsOneWidget);

    AppTranslations.currentLanguage = AppLanguage.english;
    await tester.pumpAndSettle();

    expect(find.text('No favorite addresses yet'), findsOneWidget);
    expect(
      find.text(
        'Add frequently used addresses like Home, Work, or another favorite address.',
      ),
      findsOneWidget,
    );
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('Нямате любими адреси'), findsNothing);
  });

  testWidgets(
    'add dialog translates labels and validation without losing entered values',
    (tester) async {
      AppTranslations.currentLanguage = AppLanguage.english;
      final service = _MemoryFavoritesService();
      final places = _FakePlacesService(const [
        PlaceSuggestion(placeId: 'sofia-airport', text: 'Sofia Airport'),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: FavoritesScreen(
            favoritesService: service,
            placesService: places,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Add favorite address'), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Home, Work...'), findsOneWidget);
      expect(find.text('Address'), findsOneWidget);
      expect(find.text('Start typing an address'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Add'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a name for this address'), findsOneWidget);
      expect(
        find.text('Select an address from the suggestions'),
        findsOneWidget,
      );

      AppTranslations.currentLanguage = AppLanguage.bulgarian;
      await tester.pumpAndSettle();
      expect(find.text('Добавяне на любим адрес'), findsOneWidget);
      expect(find.text('Име'), findsOneWidget);
      expect(find.text('Дом, Работа...'), findsOneWidget);
      expect(find.text('Адрес'), findsOneWidget);
      expect(find.text('Започнете да въвеждате адрес'), findsOneWidget);
      expect(find.text('Въведете име на адреса'), findsOneWidget);
      expect(find.text('Изберете адрес от предложенията'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Work Office');
      await tester.enterText(find.byType(TextField).at(1), 'Sofia');
      await tester.pump(const Duration(milliseconds: 401));
      await tester.pumpAndSettle();
      expect(places.queries, ['Sofia']);
      await tester.tap(find.text('Sofia Airport'));
      await tester.pumpAndSettle();

      AppTranslations.currentLanguage = AppLanguage.english;
      await tester.pumpAndSettle();
      expect(find.text('Add favorite address'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Work Office',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
        'Sofia Airport',
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();
      expect(service.added, hasLength(1));
      expect(service.added.single.name, 'Work Office');
      expect(service.added.single.address, 'Sofia Airport');
      expect(find.text('Work Office'), findsOneWidget);
      expect(find.text('Sofia Airport'), findsOneWidget);
    },
  );

  testWidgets('edit dialog and menu localize while preserving user data', (
    tester,
  ) async {
    AppTranslations.currentLanguage = AppLanguage.english;
    final service = _MemoryFavoritesService([_favorite]);
    await tester.pumpWidget(
      MaterialApp(home: FavoritesScreen(favoritesService: service)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit address'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'My Home',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
      'Sofia Airport',
    );

    await tester.enterText(find.byType(TextField).first, 'Home Office');
    AppTranslations.currentLanguage = AppLanguage.bulgarian;
    await tester.pumpAndSettle();
    expect(find.text('Редактиране на адрес'), findsOneWidget);
    expect(find.text('Запази'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Home Office',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
      'Sofia Airport',
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'Запази'));
    await tester.pumpAndSettle();
    expect(service.updated, hasLength(1));
    expect(service.updated.single.name, 'Home Office');
    expect(service.updated.single.address, 'Sofia Airport');
    expect(find.text('Home Office'), findsOneWidget);
    expect(find.text('Sofia Airport'), findsOneWidget);
  });

  testWidgets('delete menu and confirmation dialog are localized', (
    tester,
  ) async {
    AppTranslations.currentLanguage = AppLanguage.english;
    final service = _MemoryFavoritesService([_favorite]);
    await tester.pumpWidget(
      MaterialApp(home: FavoritesScreen(favoritesService: service)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    AppTranslations.currentLanguage = AppLanguage.bulgarian;
    await tester.pumpAndSettle();
    expect(find.text('Редактирай'), findsOneWidget);
    expect(find.text('Изтрий'), findsOneWidget);
    AppTranslations.currentLanguage = AppLanguage.english;
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete favorite address'), findsOneWidget);
    expect(
      find.text('Are you sure you want to delete "My Home"?'),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    AppTranslations.currentLanguage = AppLanguage.bulgarian;
    await tester.pumpAndSettle();
    expect(find.text('Изтриване на любим адрес'), findsOneWidget);
    expect(
      find.text('Сигурни ли сте, че искате да изтриете "My Home"?'),
      findsOneWidget,
    );
    expect(find.text('Отказ'), findsOneWidget);
    expect(find.text('Изтрий'), findsOneWidget);
    await tester.tap(find.text('Отказ'));
    await tester.pumpAndSettle();
    expect(service.deleted, isEmpty);
    expect(find.text('My Home'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Изтрий'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Изтрий'));
    await tester.pumpAndSettle();
    expect(service.deleted, ['home']);
    expect(find.text('Нямате любими адреси'), findsOneWidget);
  });
}
