import 'package:archinfotech/provider/LoadingProvider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoadingProvider', () {
    late LoadingProvider provider;
    late int notifications;

    setUp(() {
      provider = LoadingProvider();
      notifications = 0;
      provider.addListener(() => notifications++);
    });

    test('starts idle with no message', () {
      expect(provider.isLoading, isFalse);
      expect(provider.loadingMessage, isNull);
    });

    test('startLoading sets the flag and message and notifies', () {
      provider.startLoading('Saving...');

      expect(provider.isLoading, isTrue);
      expect(provider.loadingMessage, 'Saving...');
      expect(notifications, 1);
    });

    test('stopLoading clears the flag and message and notifies', () {
      provider.startLoading('Saving...');
      provider.stopLoading();

      expect(provider.isLoading, isFalse);
      expect(provider.loadingMessage, isNull);
      expect(notifications, 2);
    });

    test('whileLoading is loading during the callback and returns its result', () async {
      bool? loadingDuring;
      String? messageDuring;

      final result = await provider.whileLoading(() async {
        loadingDuring = provider.isLoading;
        messageDuring = provider.loadingMessage;
        return 42;
      }, message: 'Working');

      expect(result, 42);
      expect(loadingDuring, isTrue);
      expect(messageDuring, 'Working');
      expect(provider.isLoading, isFalse);
      expect(provider.loadingMessage, isNull);
    });

    test('whileLoading stops loading even when the callback throws', () async {
      await expectLater(
        provider.whileLoading<void>(() async {
          throw StateError('boom');
        }),
        throwsStateError,
      );

      expect(provider.isLoading, isFalse);
      expect(notifications, 2);
    });
  });
}
