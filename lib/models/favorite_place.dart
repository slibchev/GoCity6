class FavoritePlace {
  final String id;
  final String name;
  final String address;
  final String placeId;

  const FavoritePlace({
    required this.id,
    required this.name,
    required this.address,
    required this.placeId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'placeId': placeId,
    };
  }

  factory FavoritePlace.fromJson(Map<String, dynamic> json) {
    return FavoritePlace(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      placeId: json['placeId'] as String,
    );
  }
}