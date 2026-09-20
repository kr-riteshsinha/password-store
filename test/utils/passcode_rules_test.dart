import 'package:archinfotech/utils/passcode_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('newPasscodeError', () {
    test('accepts a passcode that is long enough and confirmed', () {
      expect(newPasscodeError('1234', '1234'), isNull);
    });

    test('rejects an empty or blank passcode', () {
      expect(newPasscodeError('', ''), 'Please enter a passcode');
      expect(newPasscodeError('   ', '   '), 'Please enter a passcode');
    });

    test('rejects a passcode shorter than the minimum', () {
      expect(
        newPasscodeError('123', '123'),
        'Passcode must be at least $minPasscodeLength characters',
      );
    });

    test('does not count surrounding spaces towards the minimum length', () {
      expect(newPasscodeError(' 12 ', ' 12 '), isNotNull);
    });

    test('rejects a confirmation that does not match', () {
      expect(newPasscodeError('1234', '1235'), "Passcodes don't match");
    });
  });
}
