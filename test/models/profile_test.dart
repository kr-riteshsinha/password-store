import 'package:archinfotech/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProfileEntry', () {
    final profile = ProfileEntry(
      id: 'p1',
      name: 'ritesh',
      password: '1234',
      hint: 'Favorite color?',
      answer: 'Blue',
    );

    test('toMap contains every database column', () {
      expect(profile.toMap(), {
        'id': 'p1',
        'name': 'ritesh',
        'password': '1234',
        'hint': 'Favorite color?',
        'answer': 'Blue',
      });
    });

    test('fromMap(toMap()) round-trips every field', () {
      expect(ProfileEntry.fromMap(profile.toMap()).toMap(), profile.toMap());
    });

    test('copyWith replaces only the given fields', () {
      final changed = profile.copyWith(password: '5678');

      expect(changed.password, '5678');
      expect(
        changed.toMap()..remove('password'),
        profile.toMap()..remove('password'),
      );
    });

    test('copyWith with no arguments returns an equal copy', () {
      expect(profile.copyWith().toMap(), profile.toMap());
    });
  });
}
