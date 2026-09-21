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
      final plan = planMerge(local: [v('1')], remote: [], lastSynced: const {});

      expect(actionFor(plan, '1'), MergeAction.uploadLocal);
    });

    test('an entry only the folder has is applied', () {
      final plan = planMerge(local: [], remote: [v('1')], lastSynced: const {});

      expect(actionFor(plan, '1'), MergeAction.applyRemote);
    });

    test('an empty folder never deletes anything locally', () {
      // The failure this rules out: an unreadable or newly-chosen folder
      // looking like "everything was deleted" and emptying the vault.
      final plan = planMerge(local: [v('1'), v('2'), v('3')], remote: [], lastSynced: const {});

      expect(plan.toApply, isEmpty);
      expect(plan.toUpload, hasLength(3));
    });

    test('a tombstone the folder has is applied, not ignored', () {
      final plan = planMerge(local: [], remote: [v('1', deleted: true)], lastSynced: const {});

      expect(actionFor(plan, '1'), MergeAction.applyRemote);
    });
  });

  group('agreeing', () {
    test('identical versions do nothing', () {
      final plan = planMerge(local: [v('1')], remote: [v('1')], lastSynced: const {});

      expect(actionFor(plan, '1'), MergeAction.nothing);
      expect(plan.isEmpty, isTrue);
    });
  });

  group('ordering', () {
    test('the higher revision wins, whichever side it is on', () {
      expect(
        actionFor(planMerge(local: [v('1', revision: 2)], remote: [v('1')], lastSynced: const {}), '1'),
        MergeAction.uploadLocal,
      );
      expect(
        actionFor(planMerge(local: [v('1')], remote: [v('1', revision: 2)], lastSynced: const {}), '1'),
        MergeAction.applyRemote,
      );
    });

    test('revision beats a newer timestamp', () {
      // A device whose clock is a year ahead must not win by saying so.
      final plan = planMerge(
        local: [v('1', revision: 5, updatedAt: 1000)],
        remote: [v('1', revision: 4, updatedAt: 99999999)],
        lastSynced: const {},
      );

      expect(actionFor(plan, '1'), MergeAction.uploadLocal);
    });

    test('the timestamp breaks a tie between equal revisions', () {
      final plan = planMerge(
        local: [v('1', revision: 3, updatedAt: 1000)],
        remote: [v('1', revision: 3, updatedAt: 2000)],
        lastSynced: const {},
      );

      expect(actionFor(plan, '1'), MergeAction.applyRemote);
    });

    test('the device id breaks a tie when everything else matches', () {
      final plan = planMerge(
        local: [v('1', deviceId: 'a')],
        remote: [v('1', deviceId: 'b')],
        lastSynced: const {},
      );

      // Arbitrary, but both devices reach the same answer, which is what
      // matters: without it they would disagree forever.
      expect(actionFor(plan, '1'), MergeAction.applyRemote);
    });

    test('both devices pick the same winner', () {
      final mine = v('1', revision: 2, updatedAt: 5, deviceId: 'a');
      final theirs = v('1', revision: 2, updatedAt: 5, deviceId: 'b');

      final here = planMerge(local: [mine], remote: [theirs], lastSynced: const {});
      final there = planMerge(local: [theirs], remote: [mine], lastSynced: const {});

      expect(here.decisions.single.winner!.deviceId, 'b');
      expect(there.decisions.single.winner!.deviceId, 'b');
    });
  });

  group('deletions', () {
    test('a deletion beats an edit of the same revision', () {
      final plan = planMerge(
        local: [v('1', revision: 3)],
        remote: [v('1', revision: 3, deleted: true)],
        lastSynced: const {},
      );

      expect(actionFor(plan, '1'), MergeAction.applyRemote);
    });

    test('a deletion beats an older edit', () {
      final plan = planMerge(
        local: [v('1', revision: 2)],
        remote: [v('1', revision: 3, deleted: true)],
        lastSynced: const {},
      );

      expect(actionFor(plan, '1'), MergeAction.applyRemote);
    });

    test('an entry edited after it was deleted comes back', () {
      // Deliberately re-created: the newer revision is a decision, not an
      // accident.
      final plan = planMerge(
        local: [v('1', revision: 4)],
        remote: [v('1', revision: 3, deleted: true)],
        lastSynced: const {},
      );

      expect(actionFor(plan, '1'), MergeAction.uploadLocal);
    });

    test('a deleted entry does not return from a device that never synced', () {
      final plan = planMerge(
        local: [v('1', revision: 5, deleted: true)],
        remote: [v('1', revision: 1)],
        lastSynced: const {},
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
        lastSynced: const {},
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
        lastSynced: const {},
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
      final plan = planMerge(local: a.values, remote: b.values, lastSynced: const {});
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
        final plan = planMerge(local: left.values, remote: right.values, lastSynced: const {});

        expect(plan.isEmpty, isTrue, reason: 'round $round: sync did not settle');
      }
    });

    test('a live entry is never silently dropped', () {
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

        final (left, _) = sync(a, b);

        // Falsifiable, unlike counting ids: an entry may only end up deleted
        // if some side actually deleted it. Losing one any other way is the
        // failure this whole file exists to prevent.
        for (final id in {...a.keys, ...b.keys}) {
          final ended = left[id];
          expect(ended, isNotNull, reason: 'round $round: $id disappeared');
          if (ended!.deleted) {
            expect(
              a[id]?.deleted == true || b[id]?.deleted == true,
              isTrue,
              reason: 'round $round: $id ended deleted, but neither side deleted it',
            );
          }
        }
      }
    });

    test('concurrent edits either settle or are reported, never silently dropped', () {
      final random = Random(4242);

      for (var round = 0; round < 300; round++) {
        final a = <String, ItemVersion>{};
        final b = <String, ItemVersion>{};
        final lastSynced = <String, int>{};

        for (var i = 0; i < 4; i++) {
          final id = 'item-$i';
          final base = random.nextInt(3) + 1;
          lastSynced[id] = base;
          // Both sides move on from the agreed revision, which is what makes
          // a genuine conflict — the branch the earlier property tests never
          // reached, because they passed no history at all.
          a[id] = v(
            id,
            revision: base + random.nextInt(3),
            updatedAt: random.nextInt(100),
            deviceId: 'a',
            deleted: random.nextInt(3) == 0,
          );
          b[id] = v(
            id,
            revision: base + random.nextInt(3),
            updatedAt: random.nextInt(100),
            deviceId: 'b',
            deleted: random.nextInt(3) == 0,
          );
        }

        final plan = planMerge(local: a.values, remote: b.values, lastSynced: lastSynced);

        for (final decision in plan.decisions) {
          final mine = a[decision.id]!;
          final theirs = b[decision.id]!;

          if (decision.action == MergeAction.conflict) {
            // Only ever for two genuine, differing edits. Two deletions are
            // agreement: reporting them would make the caller keep both and
            // resurrect an entry deleted on both devices.
            expect(
              mine.deleted && theirs.deleted,
              isFalse,
              reason: 'round $round: two deletions were called a conflict',
            );
            continue;
          }

          // Everything else must settle on one of the two versions.
          final winner = decision.winner;
          expect(winner, isNotNull, reason: 'round $round: no winner for ${decision.id}');
          expect(
            winner!.sameAs(mine) || winner.sameAs(theirs),
            isTrue,
            reason: 'round $round: invented a version for ${decision.id}',
          );
        }
      }
    });

    test('an entry deleted on both devices stays deleted', () {
      // Found by review: this was reported as a conflict, and the caller
      // resolves a conflict by keeping both — so deleting a password on two
      // devices brought it back, and never settled.
      final plan = planMerge(
        local: [v('1', revision: 4, deviceId: 'a', updatedAt: 10, deleted: true)],
        remote: [v('1', revision: 4, deviceId: 'b', updatedAt: 20, deleted: true)],
        lastSynced: const {'1': 3},
      );

      expect(plan.conflicts, isEmpty);
      expect(plan.decisions.single.winner!.deleted, isTrue);
    });

    test('two deletions settle in one pass', () {
      final mine = v('1', revision: 4, deviceId: 'a', updatedAt: 10, deleted: true);
      final theirs = v('1', revision: 5, deviceId: 'b', updatedAt: 20, deleted: true);

      final first = planMerge(local: [mine], remote: [theirs], lastSynced: const {'1': 3});
      final winner = first.decisions.single.winner!;
      final second = planMerge(local: [winner], remote: [winner], lastSynced: const {'1': 3});

      expect(second.isEmpty, isTrue);
    });
  });
}
