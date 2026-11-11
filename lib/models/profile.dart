/// Diet preference stored in a profile.
///
/// [allowedCategories] are TheMealDB categories that fit the diet. They are
/// used to filter search results.
enum DietPreference {
  none('No preference', []),
  vegetarian('Vegetarian', ['Vegetarian', 'Vegan']),
  vegan('Vegan', ['Vegan']);

  const DietPreference(this.label, this.allowedCategories);

  final String label;
  final List<String> allowedCategories;

  bool get filtersResults => allowedCategories.isNotEmpty;

  static DietPreference fromName(String? name) => DietPreference.values
      .firstWhere((d) => d.name == name, orElse: () => DietPreference.none);
}

/// Light/dark theme setting stored per profile.
enum ThemePreference {
  system('System'),
  light('Light'),
  dark('Dark');

  const ThemePreference(this.label);

  final String label;

  static ThemePreference fromName(String? name) => ThemePreference.values
      .firstWhere((t) => t.name == name, orElse: () => ThemePreference.system);
}

/// A local user profile. Profiles have no password on purpose: they only
/// hold non-sensitive data (nickname, avatar and cooking preferences).
class Profile {
  const Profile({
    required this.id,
    required this.nickname,
    required this.avatar,
    required this.createdAt,
    required this.updatedAt,
    this.diet = DietPreference.none,
    this.themePreference = ThemePreference.system,
  });

  final String id;
  final String nickname;
  final String avatar;
  final DietPreference diet;
  final ThemePreference themePreference;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Avatars the user can pick from.
  static const List<String> avatars = [
    '🙂', '🐻', '🦊', '🐸', '🐼', '🍕', '🧁', '🥑',
  ];

  Profile copyWith({
    String? nickname,
    String? avatar,
    DietPreference? diet,
    ThemePreference? themePreference,
    DateTime? updatedAt,
  }) {
    return Profile(
      id: id,
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
      diet: diet ?? this.diet,
      themePreference: themePreference ?? this.themePreference,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Row format for the local SQLite table `profiles`.
  Map<String, Object?> toDbMap() => {
        'id': id,
        'nickname': nickname,
        'avatar': avatar,
        'diet': diet.name,
        'theme_mode': themePreference.name,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  static Profile fromDbMap(Map<String, Object?> row) {
    return Profile(
      id: row['id'] as String,
      nickname: row['nickname'] as String,
      avatar: row['avatar'] as String,
      diet: DietPreference.fromName(row['diet'] as String?),
      themePreference: ThemePreference.fromName(row['theme_mode'] as String?),
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }
}
