import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/json_utils.dart';
import '../models/recipe.dart';

/// Error from the recipe API. [message] is safe to show to the user.
class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when the device has no internet connection.
class OfflineException extends ApiException {
  const OfflineException()
      : super("You're offline. Check your internet connection.");
}

/// Client for TheMealDB REST API (https://www.themealdb.com/api.php).
///
/// All calls are asynchronous, use HTTPS, time out after
/// [AppConfig.requestTimeout] and validate the JSON they receive.
class MealDbApi {
  MealDbApi({
    http.Client? client,
    String baseUrl = AppConfig.mealDbBaseUrl,
    String apiKey = AppConfig.mealDbApiKey,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl,
        _apiKey = apiKey {
    // Refuse to talk to the API over an unencrypted connection.
    if (!_baseUrl.startsWith('https://')) {
      throw ArgumentError('The API base URL must use HTTPS.');
    }
  }

  final http.Client _client;
  final String _baseUrl;
  final String _apiKey;

  /// Names of all categories, e.g. "Beef", "Dessert", "Vegetarian".
  Future<List<String>> fetchCategories() async {
    final items = await _getList('list.php', {'c': 'list'});
    return _readNames(items, 'strCategory');
  }

  /// Names of all cuisines ("areas") that actually have recipes,
  /// e.g. "Italian", "Mexican", "France".
  ///
  /// TheMealDB's `list.php?a=list` is not used: it returns ~195 countries,
  /// most without any recipes, and misses areas such as "France" or
  /// "India" that recipes really use. Instead, the areas are collected from
  /// the recipes themselves by searching every first letter a-z.
  Future<List<String>> fetchAreas() async {
    const letters = 'abcdefghijklmnopqrstuvwxyz';
    final results = await Future.wait(
      letters.split('').map((letter) => _getList('search.php', {'f': letter})),
    );
    final areas = <String>{
      for (final items in results) ..._readNames(items, 'strArea'),
    }.toList()
      ..sort();
    return areas;
  }

  Future<List<RecipeSummary>> filterByCategory(String category) =>
      _getSummaries('filter.php', {'c': category});

  Future<List<RecipeSummary>> filterByArea(String area) =>
      _getSummaries('filter.php', {'a': area});

  /// Recipes that contain [ingredient]. TheMealDB expects underscores
  /// instead of spaces, e.g. "chicken_breast".
  Future<List<RecipeSummary>> filterByIngredient(String ingredient) =>
      _getSummaries('filter.php', {
        'i': ingredient.trim().toLowerCase().replaceAll(' ', '_'),
      });

  /// Recipes whose name contains [query].
  Future<List<RecipeSummary>> searchByName(String query) =>
      _getSummaries('search.php', {'s': query.trim()});

  /// Full recipe by id, or null if it does not exist.
  Future<Recipe?> lookupRecipe(String id) async {
    final items = await _getList('lookup.php', {'i': id});
    return items.isEmpty ? null : Recipe.tryFromJson(items.first);
  }

  /// A random recipe ("Surprise me").
  Future<Recipe?> randomRecipe() async {
    final items = await _getList('random.php', const {});
    return items.isEmpty ? null : Recipe.tryFromJson(items.first);
  }

  Future<List<RecipeSummary>> _getSummaries(
    String endpoint,
    Map<String, String> query,
  ) async {
    final items = await _getList(endpoint, query);
    // Invalid items are skipped instead of crashing the whole list.
    return items
        .map(RecipeSummary.tryFromJson)
        .whereType<RecipeSummary>()
        .toList();
  }

  List<String> _readNames(List<Object?> items, String key) {
    return items
        .whereType<Map>()
        .map((item) => readTrimmedString(item[key], maxLength: 100))
        .whereType<String>()
        .toList();
  }

  /// Performs a GET request and returns the "meals" list from the response.
  /// TheMealDB returns `{"meals": null}` when nothing is found, which is
  /// treated as an empty list.
  Future<List<Object?>> _getList(
    String endpoint,
    Map<String, String> query,
  ) async {
    final uri = Uri.parse('$_baseUrl/$_apiKey/$endpoint')
        .replace(queryParameters: query.isEmpty ? null : query);

    final http.Response response;
    try {
      response = await _client.get(uri).timeout(AppConfig.requestTimeout);
    } on SocketException {
      throw const OfflineException();
    } on http.ClientException {
      throw const OfflineException();
    } on TimeoutException {
      throw const ApiException(
          'The recipe service took too long to respond. Please try again.');
    } on Exception catch (error) {
      // E.g. a TLS/certificate problem. Details are only logged.
      debugPrint('MealDbApi: request failed: $error');
      throw const ApiException('Could not reach the recipe service.');
    }

    if (response.statusCode != 200) {
      // Details are only logged in debug builds, never shown to the user.
      debugPrint('MealDbApi: HTTP ${response.statusCode} for $endpoint');
      throw const ApiException(
          'The recipe service is not available right now. Please try again later.');
    }

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map && decoded['meals'] is List) {
        return decoded['meals'] as List<Object?>;
      }
      return const [];
    } on FormatException {
      throw const ApiException('Received invalid data from the recipe service.');
    }
  }

  void dispose() => _client.close();
}
