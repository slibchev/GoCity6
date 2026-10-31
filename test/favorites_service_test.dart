import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxi_app/models/favorite_place.dart';
import 'package:taxi_app/services/favorites_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('favorite addresses are isolated by Passenger ID', () async {
    final passengerOne = FavoritesService(passengerId: '101');
    final passengerTwo = FavoritesService(passengerId: '202');

    await passengerOne.addFavorite(
      const FavoritePlace(
        id: 'home-1',
        name: 'Home',
        address: 'Passenger one home',
        placeId: 'place-1',
      ),
    );

    expect(
      (await passengerOne.getFavorites()).single.address,
      'Passenger one home',
    );
    expect(await passengerTwo.getFavorites(), isEmpty);
  });
}
