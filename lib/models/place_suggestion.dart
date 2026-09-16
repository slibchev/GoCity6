class PlaceSuggestion {
  final String placeId;
  final String text;

  const PlaceSuggestion({required this.placeId, required this.text});

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      placeId: json['placeId'] as String,
      text: json['text'] as String,
    );
  }
}
