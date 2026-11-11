/// One line on the shopping list.
class ShoppingItem {
  const ShoppingItem({
    required this.name,
    this.id,
    this.measure = '',
    this.recipeName,
    this.checked = false,
  });

  /// Database id. Null until the item has been saved.
  final int? id;
  final String name;
  final String measure;

  /// Name of the recipe the item was added from, if any.
  final String? recipeName;
  final bool checked;

  String get displayText => measure.isEmpty ? name : '$name ($measure)';

  Map<String, Object?> toDbMap(String profileId) => {
        if (id != null) 'id': id,
        'profile_id': profileId,
        'name': name,
        'measure': measure,
        'recipe_name': recipeName,
        'checked': checked ? 1 : 0,
      };

  static ShoppingItem fromDbMap(Map<String, Object?> row) => ShoppingItem(
        id: row['id'] as int,
        name: row['name'] as String,
        measure: (row['measure'] as String?) ?? '',
        recipeName: row['recipe_name'] as String?,
        checked: (row['checked'] as int) == 1,
      );

  Map<String, Object?> toCloudMap() => {
        'name': name,
        'measure': measure,
        'recipeName': recipeName,
        'checked': checked,
      };
}
