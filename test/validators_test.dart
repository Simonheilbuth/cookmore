import 'package:cookmore/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nickname', () {
    test('accepts normal nicknames', () {
      expect(Validators.nickname('Simon'), isNull);
      expect(Validators.nickname('Chef_42'), isNull);
      expect(Validators.nickname('Søren'), isNull);
    });

    test('rejects too short or too long nicknames', () {
      expect(Validators.nickname('A'), isNotNull);
      expect(Validators.nickname('   '), isNotNull);
      expect(Validators.nickname('A' * 21), isNotNull);
    });

    test('rejects special characters', () {
      expect(Validators.nickname('<script>'), isNotNull);
      expect(Validators.nickname('Simon; DROP TABLE'), isNotNull);
    });
  });

  group('ingredient', () {
    test('accepts letters, spaces and hyphens', () {
      expect(Validators.ingredient('chicken breast'), isNull);
      expect(Validators.ingredient('pak-choi'), isNull);
    });

    test('rejects empty, numbers and symbols', () {
      expect(Validators.ingredient(''), isNotNull);
      expect(Validators.ingredient('200g'), isNotNull);
      expect(Validators.ingredient('rice&beans'), isNotNull);
    });

    test('rejects too long input', () {
      expect(Validators.ingredient('a' * 31), isNotNull);
    });

    test('cleanIngredient trims and collapses spaces', () {
      expect(Validators.cleanIngredient('  red   onion '), 'red onion');
    });
  });
}
