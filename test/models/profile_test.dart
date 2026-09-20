import 'package:archinfotech/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProfileEntry', () {
    final profile = ProfileEntry(id: 'p1', name: 'ritesh');

    test('toMap contains every database column', () {
      expect(profile.toMap(), {'id': 'p1', 'name': 'ritesh'});
    });

    test('holds no passcode, question or answer', () {
      // They are not stored: the passcode and answer wrap the database key,
      // and the question lives in vault_meta.json.
      expect(profile.toMap().keys, ['id', 'name']);
    });

    test('fromMap(toMap()) round-trips every field', () {
      expect(ProfileEntry.fromMap(profile.toMap()).toMap(), profile.toMap());
    });

    test('copyWith replaces only the given fields', () {
      final changed = profile.copyWith(name: 'someone');

      expect(changed.name, 'someone');
      expect(changed.id, profile.id);
    });

    test('copyWith with no arguments returns an equal copy', () {
      expect(profile.copyWith().toMap(), profile.toMap());
    });
  });
}
