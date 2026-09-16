import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/place_suggestion.dart';

class BackendPlacesService {
  final String baseUrl;

  const BackendPlacesService({this.baseUrl = 'http://localhost:8080'});

  Future<List<PlaceSuggestion>> autocomplete({
    required String input,
    String? sessionToken,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/places/autocomplete'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'input': input,
        if (sessionToken != null && sessionToken.isNotEmpty)
          'sessionToken': sessionToken,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Places autocomplete failed with status '
        '${response.statusCode}.',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final suggestions = data['suggestions'] as List<dynamic>? ?? <dynamic>[];

    return suggestions
        .map((item) => PlaceSuggestion.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
