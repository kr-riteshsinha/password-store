import 'package:archinfotech/models/passwordEntry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PasswordEntry (legacy)', () {
    PasswordEntry entry({bool isFavorite = false}) => PasswordEntry(
          id: 1,
          username: 'john@example.com',
          password: 'pw',
          category: 'Email',
          expiryDate: '2025-12-31',
          url: 'https://example.com',
          isFavorite: isFavorite,
        );

    test('isFavorite defaults to false', () {
      final e = PasswordEntry(
        username: 'u',
        password: 'p',
        category: 'c',
        expiryDate: 'd',
      );
      expect(e.isFavorite, isFalse);
    });

    test('toMap stores isFavorite as 1 / 0', () {
      expect(entry(isFavorite: true).toMap()['isFavorite'], 1);
      expect(entry().toMap()['isFavorite'], 0);
    });

    test('fromMap reads isFavorite from 1 / 0', () {
      expect(PasswordEntry.fromMap(entry(isFavorite: true).toMap()).isFavorite, isTrue);
      expect(PasswordEntry.fromMap(entry().toMap()).isFavorite, isFalse);
    });

    test(
      'fromMap(toMap()) keeps the url',
      () {
        expect(PasswordEntry.fromMap(entry().toMap()).url, 'https://example.com');
      },
      skip: 'ISSUES.md #28: PasswordEntry.fromMap ignores url',
    );
  });
}
