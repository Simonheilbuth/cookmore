import 'dart:convert';

import 'package:cookmore/services/meal_db_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('fetchAreas', () {
    test('collects unique areas from recipes, sorted, ignoring empty letters',
        () async {
      final requestedLetters = <String>[];
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('/search.php'));
        final letter = request.url.queryParameters['f']!;
        requestedLetters.add(letter);
        final meals = switch (letter) {
          'a' => [
              {'strArea': 'Italian'},
              {'strArea': 'France'},
            ],
          'b' => [
              {'strArea': 'Italian'},
              {'strArea': 'British'},
            ],
          _ => null, // TheMealDB returns {"meals": null} when empty.
        };
        return http.Response(jsonEncode({'meals': meals}), 200);
      });

      final api = MealDbApi(client: client);
      final areas = await api.fetchAreas();

      expect(areas, ['British', 'France', 'Italian']);
      expect(requestedLetters.length, 26);
    });

    test('throws ApiException when the service fails', () async {
      final client = MockClient((_) async => http.Response('oops', 500));
      final api = MealDbApi(client: client);

      expect(api.fetchAreas(), throwsA(isA<ApiException>()));
    });
  });
}
