import 'json_utils.dart';

/// A short version of a recipe, as returned by list and filter endpoints.
class RecipeSummary {
  const RecipeSummary({
    required this.id,
    required this.name,
    this.thumbnailUrl,
  });

  final String id;
  final String name;
  final String? thumbnailUrl;

  static final RegExp _idPattern = RegExp(r'^\d{1,10}$');

  /// Parses a meal object from TheMealDB.
  /// Returns null if required fields are missing or invalid.
  static RecipeSummary? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = readTrimmedString(json['idMeal'], maxLength: 10);
    final name = readTrimmedString(json['strMeal'], maxLength: 200);
    if (id == null || name == null || !_idPattern.hasMatch(id)) return null;
    return RecipeSummary(
      id: id,
      name: name,
      thumbnailUrl: readHttpsUrl(json['strMealThumb']),
    );
  }

  @override
  bool operator ==(Object other) => other is RecipeSummary && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// One ingredient line in a recipe, e.g. "Spaghetti" / "200g".
class RecipeIngredient {
  const RecipeIngredient({required this.name, this.measure = ''});

  final String name;
  final String measure;

  /// Text used in lists, e.g. "200g Spaghetti".
  String get displayText => measure.isEmpty ? name : '$measure $name';
}

/// A full recipe with ingredients and instructions.
class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.instructions,
    required this.ingredients,
    this.category,
    this.area,
    this.thumbnailUrl,
    this.youtubeUrl,
    this.sourceUrl,
    this.tags = const [],
  });

  final String id;
  final String name;
  final String? category;
  final String? area;
  final String instructions;
  final String? thumbnailUrl;
  final String? youtubeUrl;
  final String? sourceUrl;
  final List<String> tags;
  final List<RecipeIngredient> ingredients;

  /// TheMealDB stores ingredients in numbered fields strIngredient1..20.
  static const int _ingredientSlots = 20;

  RecipeSummary get summary =>
      RecipeSummary(id: id, name: name, thumbnailUrl: thumbnailUrl);

  /// Instructions split into readable steps.
  /// Empty lines and "STEP 1"-style headings are removed.
  List<String> get steps {
    final headingPattern = RegExp(r'^step\s*\d+[:.]?$', caseSensitive: false);
    return instructions
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !headingPattern.hasMatch(line))
        .toList();
  }

  /// Parses a full meal object from TheMealDB (or from the local cache,
  /// which uses the same format). Returns null if the data is invalid.
  static Recipe? tryFromJson(Object? json) {
    final summary = RecipeSummary.tryFromJson(json);
    if (summary == null || json is! Map) return null;

    final ingredients = <RecipeIngredient>[];
    for (var i = 1; i <= _ingredientSlots; i++) {
      final name = readTrimmedString(json['strIngredient$i'], maxLength: 100);
      if (name == null) continue;
      final measure =
          readTrimmedString(json['strMeasure$i'], maxLength: 100) ?? '';
      ingredients.add(RecipeIngredient(name: name, measure: measure));
    }

    final tagText = readTrimmedString(json['strTags'], maxLength: 300);
    final tags = tagText == null
        ? const <String>[]
        : tagText
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList();

    return Recipe(
      id: summary.id,
      name: summary.name,
      thumbnailUrl: summary.thumbnailUrl,
      category: readTrimmedString(json['strCategory'], maxLength: 100),
      area: readTrimmedString(json['strArea'], maxLength: 100),
      instructions: readTrimmedString(json['strInstructions']) ?? '',
      youtubeUrl: readHttpsUrl(json['strYoutube']),
      sourceUrl: readHttpsUrl(json['strSource']),
      tags: tags,
      ingredients: ingredients,
    );
  }

  /// Serialises the recipe in TheMealDB's format so the same parser can
  /// read both API responses and cached copies.
  Map<String, Object?> toJson() {
    final json = <String, Object?>{
      'idMeal': id,
      'strMeal': name,
      'strCategory': category,
      'strArea': area,
      'strInstructions': instructions,
      'strMealThumb': thumbnailUrl,
      'strYoutube': youtubeUrl,
      'strSource': sourceUrl,
      'strTags': tags.isEmpty ? null : tags.join(','),
    };
    for (var i = 0; i < ingredients.length && i < _ingredientSlots; i++) {
      json['strIngredient${i + 1}'] = ingredients[i].name;
      json['strMeasure${i + 1}'] = ingredients[i].measure;
    }
    return json;
  }

  /// Plain-text version of the recipe used by the share sheet.
  String toShareText() {
    final buffer = StringBuffer()
      ..writeln(name)
      ..writeln();
    buffer.writeln('Ingredients:');
    for (final ingredient in ingredients) {
      buffer.writeln('- ${ingredient.displayText}');
    }
    buffer
      ..writeln()
      ..writeln('Instructions:');
    final allSteps = steps;
    for (var i = 0; i < allSteps.length; i++) {
      buffer.writeln('${i + 1}. ${allSteps[i]}');
    }
    buffer
      ..writeln()
      ..writeln('Shared from CookMore');
    return buffer.toString();
  }
}
