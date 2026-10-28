import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Edit Profile Logic Tests', () {
    test('Name validation requires minimum 3 characters', () {
      bool isValidName(String name) => name.trim().length >= 3;

      expect(isValidName(''), isFalse);
      expect(isValidName('a'), isFalse);
      expect(isValidName('ab'), isFalse);
      expect(isValidName('  ab  '), isFalse);
      expect(isValidName('abc'), isTrue);
      expect(isValidName('John'), isTrue);
      expect(isValidName('  Suriya  '), isTrue);
    });

    test('Initial letter fallback uses first letter of name capitalized', () {
      String getInitial(String name, String fallbackName) {
        final trimmed = name.trim();
        if (trimmed.isNotEmpty) {
          return trimmed[0].toUpperCase();
        }
        if (fallbackName.trim().isNotEmpty) {
          return fallbackName.trim()[0].toUpperCase();
        }
        return '';
      }

      expect(getInitial('suriyaprakash', ''), 'S');
      expect(getInitial('john doe', ''), 'J');
      expect(getInitial('', 'Alice'), 'A');
      expect(getInitial('', ''), '');
    });
  });
}
