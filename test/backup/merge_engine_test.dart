import 'dart:math';

import 'package:archinfotech/backup/merge_engine.dart';
import 'package:archinfotech/models/login_entry.dart';
import 'package:flutter_test/flutter_test.dart';

ItemVersion v(
  String id, {
  int revision = 1,
  int updatedAt = 1000,
  String deviceId = 'a',
  bool deleted = false,
}) =>
    ItemVersion(
      id: id,
      revision: revision,
      updatedAt: updatedAt,
      deviceId: deviceId,
      deleted: deleted,
    );

MergeAction actionFor(MergePlan plan, String id) =>
    plan.decisions.firstWhere((d) => d.id == id).action;

void main() {
  group('one side only', () {
    test('an entry only this device has is uploaded', () {
      final plan = planMerge(local: [v('1')], remote: []);

      expect(actionFor(plan, '1'), MergeAction.uploadLocal);
    });

    test('an entry only the folder has is applied', () {
      final plan = planMerge(local: [], remote: [v('1')]);

      expect(actionFor(plan, '1'), MergeAction.applyRemote);
    });

    test('an empty folder never deletes anything locally', () {
      // The failure this rules out: an unreadable or newly-chosen folder
      // looking like "everything was deleted" and emptying the vault.
      final plan = planMerge(local: [v('1'), v('2'), v('3')], remote: []);

      expect(plan.toApply, isEmpty);
      expect(plan.toUpload, hasLength(3));
    });

    test('a tombstone the folder has is applied, not ignored', () {
      final plan = planMerge(local: [], remote: [v('1', deleted: true)]);

      expect(actionFor(plan, '1'), MergeAction.applyRemote);
    });
  });

  group('agreeing', () {
    test('identical versions do nothing', () {
      final plan = planMerge(local: [v('1')], remote: [v('1')]);

      expect(actionFor(plan, '1'), MergeAction.nothing);
      expect(plan.isEmpty, isTrue);
    });
  });

  group('ordering', () {
    test('the higher revision wins, whichever side it is on', () {
      expect(
        actionFor(planMerge(local: [v('1', revision: 2)], remote: [v('1')]), '1'),
        MergeAction.uploadLocal,
      );
      expect(
        actionFor(planMerge(local: [v('1')], remote: [v('1', revision: 2)]), '1'),
        MergeAction.applyRemote,
      );
    });

    test('revision beats a newer timestamp', () {
      // A device whose clock is a year ahead must not win by saying so.
      final plan = planMerge(
        local: [v('1', revision: 5, updatedAt: 1000)],
        remote: [v('1', revision: 4, updatedAt: 99999999)],
      );

      expect(actionFor(plan, '1'), MergeAction.uploadLocal);
    });

    test('the timestamp breaks a tie between equal revisions', () {
      final plan = planMerge(
        local: [v('1', revision: 3, updatedAt: 1000)],
        remote: [v('1', revision: 3, updatedAt: 2000)],
      );

      expect(actionFor(plan, '1'), MergeAction.applyRemote);
    });

    test('the device id breaks a tie when everything else matches', () {
      final plan = planMerge(
        local: [v('1', deviceId: 'a')],
        remote: [v('1', deviceId: 'b')],
      );

      // Arbitrary, but both devices reach the same answer, which is what
      // matters: without it they would disagree forever.
      expect(actionFor(plan, '1'), MergeAction.applyRemote);
    });

    test('both devices pick the same winner', () {
      final mine = v('1', revision: 2, updatedAt: 5, deviceId: 'a');
      final theirs = v('1', revision: 2, updatedAt: 5, deviceId: 'b');

      final here = planMerge(local: [mine], remote: [theirs]);
      final there = planMerge(local: [theirs], remote: [mine]);

      expect(here.decisions.single.winner!.deviceId, 'b');
      expect(there.decisions.single.winner!.deviceId, 'b');
    });
  });

  group('deletions', () {
    test('a deletion beats an edit of the same revision', () {
      final plan = planMerge(
        local: [v('1', revision: 3)],
        remote: [v('1', revision: 3, deleted: true)],
      );

      expect(actionFor(plan, '1'), MergeAction.applyRemote);
    });

    test('a deletion beats an older edit', () {
      final plan = planMerge(
        local: [v('1', revision: 2)],
        remote: [v('1', revision: 3, deleted: true)],
      );

      expect(actionFor(plan, '1'), MergeAction.applyRemote);
    });

    test('an entry edited after it was deleted comes back', () {
      // Deliberately re-created: the newer revision is a decision, not an
      // accident.
      final plan = planMerge(
        local: [v('1', revision: 4)],
        remote: [v('1', revision: 3, deleted: true)],
      );

      expect(actionFor(plan, '1'), MergeAction.uploadLocal);
    });

    test('a deleted entry does not return from a device that never synced', () {
      final plan = planMerge(
        local: [v('1', revision: 5, deleted: true)],
        remote: [v('1', revision: 1)],
      );

      expect(actionFor(plan, '1'), MergeAction.uploadLocal);
      expect(plan.decisions.single.winner!.deleted, isTrue);
    });
  });

  group('conflicts', () {
    test('both sides changed since they last agreed', () {
      final plan = planMerge(
        local: [v('1', revision: 3, deviceId: 'a')],
        remote: [v('1', revision: 4, deviceId: 'b')],
        lastSynced: {'1': 2},
      );

      expect(actionFor(plan, '1'), MergeAction.conflict);
      expect(plan.conflicts, hasLength(1));
    });

    test('one side merely being behind is not a conflict', () {
      final plan = planMerge(
        local: [v('1', revision: 2)],
        remote: [v('1', revision: 5, deviceId: 'b')],
        lastSynced: {'1': 2},
      );

      expect(actionFor(plan, '1'), MergeAction.applyRemote);
    });

    test('without a record of agreement, nothing is called a conflict', () {
      // Otherwise the first sync between two devices would flag every entry.
      final plan = planMerge(
        local: [v('1', revision: 3, deviceId: 'a')],
        remote: [v('1', revision: 4, deviceId: 'b')],
      );

      expect(actionFor(plan, '1'), MergeAction.applyRemote);
    });

    test('a deletion settles a would-be conflict instead of asking', () {
      // Asking "deleted or edited?" would mean offering to resurrect an
      // entry the user deliberately removed. The edit is still in a snapshot.
      final plan = planMerge(
        local: [v('1', revision: 4, deviceId: 'a')],
        remote: [v('1', revision: 5, deviceId: 'b', deleted: true)],
        lastSynced: {'1': 2},
      );

      expect(actionFor(plan, '1'), MergeAction.applyRemote);
      expect(plan.decisions.single.winner!.deleted, isTrue);
    });

    test('a conflict names neither side the winner', () {
      final plan = planMerge(
        local: [v('1', revision: 3)],
        remote: [v('1', revision: 4, deviceId: 'b')],
        lastSynced: {'1': 2},
      );

      expect(plan.decisions.single.winner, isNull);
    });
  });

  group('the plan', () {
    test('is ordered by id, so the same inputs give the same plan', () {
      final plan = planMerge(
        local: [v('c'), v('a')],
        remote: [v('b'), v('d')],
      );

      expect(plan.decisions.map((d) => d.id), ['a', 'b', 'c', 'd']);
    });

    test('reads an entry straight from the database row', () {
      final entry = LoginEntry(
        id: '1',
        title: 'GitHub',
        username: 'octocat',
        password: 'pw',
        website: 'https://github.com',
        updatedAt: 42,
        revision: 7,
        deviceId: 'device-a',
        deletedAt: 43,
      );

      final version = ItemVersion.of(entry);

      expect(version.id, '1');
      expect(version.revision, 7);
      expect(version.updatedAt, 42);
      expect(version.deviceId, 'device-a');
      expect(version.deleted, isTrue);
    });
  });

  group('convergence', () {
    /// Applies a plan to both sides and returns what each ends up with.
    (Map<String, ItemVersion>, Map<String, ItemVersion>) sync(
      Map<String, ItemVersion> a,
      Map<String, ItemVersion> b,
    ) {
      final plan = planMerge(local: a.values, remote: b.values);
      final left = {...a};
      final right = {...b};
      for (final decision in plan.decisions) {
        switch (decision.action) {
          case MergeAction.applyRemote:
            left[decision.id] = decision.remote!;
          case MergeAction.uploadLocal:
            right[decision.id] = decision.local!;
          case MergeAction.nothing:
            break;
          case MergeAction.conflict:
            break;
        }
      }
      return (left, right);
    }

    test('two replicas agree after one pass, from random histories', () {
      final random = Random(20261003);

      for (var round = 0; round < 300; round++) {
        final a = <String, ItemVersion>{};
        final b = <String, ItemVersion>{};

        for (var i = 0; i < 6; i++) {
          final id = 'item-${random.nextInt(4)}';
          final version = v(
            id,
            revision: random.nextInt(5) + 1,
            updatedAt: random.nextInt(1000),
            deviceId: random.nextBool() ? 'a' : 'b',
            deleted: random.nextInt(4) == 0,
          );
          (random.nextBool() ? a : b)[id] = version;
        }

        final (left, right) = sync(a, b);

        expect(
          left.map((k, v) => MapEntry(k, v.toString())),
          right.map((k, v) => MapEntry(k, v.toString())),
          reason: 'round $round: the two sides ended up different',
        );
      }
    });

    test('a second pass changes nothing', () {
      final random = Random(7);

      for (var round = 0; round < 200; round++) {
        final a = <String, ItemVersion>{};
        final b = <String, ItemVersion>{};
        for (var i = 0; i < 5; i++) {
          final id = 'item-${random.nextInt(3)}';
          (random.nextBool() ? a : b)[id] = v(
            id,
            revision: random.nextInt(4) + 1,
            updatedAt: random.nextInt(100),
            deviceId: random.nextBool() ? 'a' : 'b',
            deleted: random.nextInt(3) == 0,
          );
        }

        final (left, right) = sync(a, b);
        final plan = planMerge(local: left.values, remote: right.values);

        expect(plan.isEmpty, isTrue, reason: 'round $round: sync did not settle');
      }
    });

    test('no live entry is ever lost without a tombstone', () {
      final random = Random(99);

      for (var round = 0; round < 300; round++) {
        final a = <String, ItemVersion>{};
        final b = <String, ItemVersion>{};
        for (var i = 0; i < 6; i++) {
          final id = 'item-${random.nextInt(4)}';
          (random.nextBool() ? a : b)[id] = v(
            id,
            revision: random.nextInt(5) + 1,
            updatedAt: random.nextInt(500),
            deviceId: random.nextBool() ? 'a' : 'b',
            deleted: random.nextInt(4) == 0,
          );
        }
        final before = {...a, ...b}.keys.toSet();

        final (left, _) = sync(a, b);

        // Every id still exists somewhere afterwards: an entry may end up
        // deleted, but it must never simply vanish.
        expect(left.keys.toSet(), before, reason: 'round $round: an id disappeared');
      }
    });
  });
}
