import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/favorite_place.dart';

class FavoritesService {
  static const String _favoritesKey = 'favoritePlaces';

  const FavoritesService();

  Future<List<FavoritePlace>> getFavorites() async {
    final preferences = await SharedPreferences.getInstance();

    final storedFavorites =
        preferences.getStringList(_favoritesKey) ?? <String>[];

    final favorites = <FavoritePlace>[];

    for (final storedFavorite in storedFavorites) {
      try {
        final decoded = jsonDecode(storedFavorite);

        if (decoded is Map<String, dynamic>) {
          favorites.add(FavoritePlace.fromJson(decoded));
        }
      } catch (_) {
        // Пропускаме повреден запис, без да блокираме останалите.
      }
    }

    return favorites;
  }

  Future<void> addFavorite(FavoritePlace favorite) async {
    final favorites = await getFavorites();

    favorites.add(favorite);

    await _saveFavorites(favorites);
  }

  Future<void> updateFavorite(FavoritePlace favorite) async {
    final favorites = await getFavorites();

    final index = favorites.indexWhere(
      (item) => item.id == favorite.id,
    );

    if (index == -1) {
      return;
    }

    favorites[index] = favorite;

    await _saveFavorites(favorites);
  }

  Future<void> deleteFavorite(String id) async {
    final favorites = await getFavorites();

    favorites.removeWhere(
      (favorite) => favorite.id == id,
    );

    await _saveFavorites(favorites);
  }

  Future<void> _saveFavorites(
    List<FavoritePlace> favorites,
  ) async {
    final preferences = await SharedPreferences.getInstance();

    final encodedFavorites = favorites
        .map(
          (favorite) => jsonEncode(favorite.toJson()),
        )
        .toList();

    await preferences.setStringList(
      _favoritesKey,
      encodedFavorites,
    );
  }
}