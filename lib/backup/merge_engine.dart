/// Deciding what a sync should do with each entry.
///
/// Pure: no files, no database, no clock. Everything here is a function of
/// its arguments, because this is where data loss would live
/// (`docs/sync-design.md` §5.2). Reading and writing is somebody else's job.
library;

import '../models/login_entry.dart';

/// What one side knows about one entry: enough to order two versions of it,
/// and nothing that needs decrypting.
class ItemVersion implements Comparable<ItemVersion> {
  final String id;

  /// Counts changes. Compared first, so a device with a wrong clock cannot
  /// win by claiming the future.
  final int revision;

  /// UTC milliseconds. Only breaks ties between equal revisions.
  final int updatedAt;

  /// Breaks the remaining ties, so two devices always agree on the winner
  /// even when everything else matches.
  final String deviceId;

  /// Whether this version is a tombstone.
  final bool deleted;

  const ItemVersion({
    required this.id,
    required this.revision,
    required this.updatedAt,
    required this.deviceId,
    this.deleted = false,
  });

  factory ItemVersion.of(LoginEntry entry) => ItemVersion(
        id: entry.id,
        revision: entry.revision,
        updatedAt: entry.updatedAt,
        deviceId: entry.deviceId,
        deleted: entry.isDeleted,
      );

  /// Orders two versions of the same entry. Later sorts greater.
  @override
  int compareTo(ItemVersion other) {
    if (revision != other.revision) return revision.compareTo(other.revision);
    if (updatedAt != other.updatedAt) return updatedAt.compareTo(other.updatedAt);
    return deviceId.compareTo(other.deviceId);
  }

  /// Whether this is the same version, not merely an equal-ranking one.
  bool sameAs(ItemVersion other) =>
      id == other.id &&
      revision == other.revision &&
      updatedAt == other.updatedAt &&
      deviceId == other.deviceId &&
      deleted == other.deleted;

  @override
  String toString() =>
      'ItemVersion($id r$revision @$updatedAt by $deviceId${deleted ? ' deleted' : ''})';
}

/// What to do about one entry.
enum MergeAction {
  /// Take the remote version, including a deletion.
  applyRemote,

  /// Send the local version, including a deletion.
  uploadLocal,

  /// Both sides already agree.
  nothing,

  /// Both sides changed it since they last agreed. Never resolved silently:
  /// the caller keeps both, the loser becoming a conflicted copy.
  conflict,
}

/// One entry's verdict.
class MergeDecision {
  final String id;
  final MergeAction action;
  final ItemVersion? local;
  final ItemVersion? remote;

  const MergeDecision({
    required this.id,
    required this.action,
    this.local,
    this.remote,
  });

  /// The version that wins, for the actions where one does.
  ItemVersion? get winner => switch (action) {
        MergeAction.applyRemote => remote,
        MergeAction.uploadLocal => local,
        MergeAction.nothing => local ?? remote,
        MergeAction.conflict => null,
      };

  @override
  String toString() => 'MergeDecision($id: ${action.name})';
}

/// Everything a single sync pass should do.
class MergePlan {
  final List<MergeDecision> decisions;

  const MergePlan(this.decisions);

  List<MergeDecision> get toApply =>
      decisions.where((d) => d.action == MergeAction.applyRemote).toList();

  List<MergeDecision> get toUpload =>
      decisions.where((d) => d.action == MergeAction.uploadLocal).toList();

  List<MergeDecision> get conflicts =>
      decisions.where((d) => d.action == MergeAction.conflict).toList();

  bool get isEmpty => decisions.every((d) => d.action == MergeAction.nothing);
}

/// Works out what a sync should do, given what each side has.
///
/// [lastSynced] is the revision this device last saw agreed for each id. It
/// is what makes a genuine conflict — both sides moved on since they last
/// agreed — distinguishable from one side simply being behind. Without it,
/// every difference would look like a conflict, and the app would nag about
/// changes it could safely apply.
MergePlan planMerge({
  required Iterable<ItemVersion> local,
  required Iterable<ItemVersion> remote,
  // Required, not defaulted: a caller that forgot it would compile, pass
  // every test, and silently resolve every concurrent edit by discarding one
  // side. Callers with genuinely no history pass `const {}` and mean it.
  required Map<String, int> lastSynced,
}) {
  final localById = {for (final item in local) item.id: item};
  final remoteById = {for (final item in remote) item.id: item};

  final decisions = <MergeDecision>[];
  // Sorted so a plan is stable: the same inputs always produce the same
  // order, which makes failures reproducible and tests honest.
  final ids = {...localById.keys, ...remoteById.keys}.toList()..sort();

  for (final id in ids) {
    final mine = localById[id];
    final theirs = remoteById[id];

    // Only one side has it. An entry the other side has never seen is not a
    // deletion: it is news. Note what this rules out — a remote listing that
    // comes back empty can only ever produce uploads, never local deletions.
    if (theirs == null) {
      decisions.add(MergeDecision(id: id, action: MergeAction.uploadLocal, local: mine));
      continue;
    }
    if (mine == null) {
      decisions.add(MergeDecision(id: id, action: MergeAction.applyRemote, remote: theirs));
      continue;
    }

    if (mine.sameAs(theirs)) {
      decisions.add(MergeDecision(
        id: id,
        action: MergeAction.nothing,
        local: mine,
        remote: theirs,
      ));
      continue;
    }

    final base = lastSynced[id];
    final bothMovedOn =
        base != null && mine.revision > base && theirs.revision > base;

    if (bothMovedOn && !_deletionSettlesIt(mine, theirs)) {
      decisions.add(MergeDecision(
        id: id,
        action: MergeAction.conflict,
        local: mine,
        remote: theirs,
      ));
      continue;
    }

    decisions.add(MergeDecision(
      id: id,
      action: _winner(mine, theirs) == theirs
          ? MergeAction.applyRemote
          : MergeAction.uploadLocal,
      local: mine,
      remote: theirs,
    ));
  }

  return MergePlan(decisions);
}

/// A deletion is not a conflict worth asking about.
///
/// If one side deleted the entry and the other edited it, the deletion wins
/// as long as it is not older. Asking the user to choose between "gone" and
/// "changed" would mean resurrecting entries they deliberately removed — and
/// the edit is still in a snapshot if they want it back.
bool _deletionSettlesIt(ItemVersion mine, ItemVersion theirs) {
  // Both deleted is agreement, not a conflict — even though the tombstones
  // differ in device and timestamp. Calling it a conflict would make the
  // caller keep both, so an entry deleted on two devices would reappear:
  // exactly what the deletion rule exists to prevent. It would also never
  // settle, being re-reported on every later pass.
  if (mine.deleted && theirs.deleted) return true;

  if (mine.deleted == theirs.deleted) return false;
  final deletion = mine.deleted ? mine : theirs;
  final edit = mine.deleted ? theirs : mine;
  return deletion.revision >= edit.revision;
}

ItemVersion _winner(ItemVersion mine, ItemVersion theirs) {
  // Tombstones beat entries of the same or older revision, whichever side
  // they are on.
  if (mine.deleted != theirs.deleted) {
    final deletion = mine.deleted ? mine : theirs;
    final edit = mine.deleted ? theirs : mine;
    if (deletion.revision >= edit.revision) return deletion;
    return edit;
  }
  return mine.compareTo(theirs) >= 0 ? mine : theirs;
}
