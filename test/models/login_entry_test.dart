import 'package:archinfotech/models/login_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoginEntry', () {
    final entry = LoginEntry(
      id: 'id-1',
      title: 'GitHub',
      username: 'octocat',
      password: 's3cret!',
      website: 'https://github.com',
      totpSecret: 'JBSWY3DPEHPK3PXP',
    );

    test('toMap contains every database column', () {
      expect(entry.toMap(), {
        'id': 'id-1',
        'title': 'GitHub',
        'username': 'octocat',
        'password': 's3cret!',
        'website': 'https://github.com',
        'totpSecret': 'JBSWY3DPEHPK3PXP',
      });
    });

    test('fromMap(toMap()) round-trips every field', () {
      expect(LoginEntry.fromMap(entry.toMap()).toMap(), entry.toMap());
    });

    test('totpSecret is optional', () {
      final noTotp = LoginEntry(
        id: 'id-2',
        title: 'Email',
        username: 'me@example.com',
        password: 'pw',
        website: '',
      );

      expect(noTotp.toMap()['totpSecret'], isNull);
      expect(LoginEntry.fromMap(noTotp.toMap()).totpSecret, isNull);
    });
  });
}
