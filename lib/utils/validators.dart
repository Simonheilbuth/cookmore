/// Validation of user input.
///
/// Every validator returns an error message for the user, or null when the
/// input is valid. The messages never contain technical details.
class Validators {
  Validators._();

  static const int nicknameMinLength = 2;
  static const int nicknameMaxLength = 20;
  static const int ingredientMaxLength = 30;

  static final RegExp _nicknamePattern =
      RegExp(r"^[\p{L}\p{N} _'\-]+$", unicode: true);

  /// Letters, spaces and hyphens only, e.g. "chicken breast" or "pak-choi".
  static final RegExp _ingredientPattern =
      RegExp(r'^[\p{L} \-]+$', unicode: true);

  static String? nickname(String? input) {
    final value = input?.trim() ?? '';
    if (value.length < nicknameMinLength) {
      return 'Nickname must be at least $nicknameMinLength characters.';
    }
    if (value.length > nicknameMaxLength) {
      return 'Nickname can be at most $nicknameMaxLength characters.';
    }
    if (!_nicknamePattern.hasMatch(value)) {
      return 'Use letters, numbers, spaces, - or _ only.';
    }
    return null;
  }

  static String? ingredient(String? input) {
    final value = cleanIngredient(input ?? '');
    if (value.isEmpty) return 'Type an ingredient first.';
    if (value.length > ingredientMaxLength) {
      return 'An ingredient can be at most $ingredientMaxLength characters.';
    }
    if (!_ingredientPattern.hasMatch(value)) {
      return 'Use letters, spaces and hyphens only.';
    }
    return null;
  }

  /// Trims the text and collapses repeated whitespace.
  static String cleanIngredient(String input) =>
      input.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// Same as [cleanIngredient] but for nicknames.
  static String cleanNickname(String input) =>
      input.trim().replaceAll(RegExp(r'\s+'), ' ');
}
