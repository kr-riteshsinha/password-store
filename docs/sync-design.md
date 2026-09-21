# Bring-your-own-storage sync — design discussion

**Status:** draft for discussion. Nothing here is built. Decisions marked **OPEN** need a
call before any code is written.

The README promises a vault you sync through *your own* iCloud Drive, Google Drive or
bucket: no project server, no project account, ciphertext only. This document works out
what that actually requires, what it costs, and where it can go wrong.

---

## 1. What we already have

The encryption work (#1, #2, #3) left us in a good position, mostly by accident of one
choice: **the database key is random and wrapped, not derived.**

```
passcode ──Argon2id──> KEK ──AES-GCM──> [database key] ──> SQLCipher
answer   ──Argon2id──> KEK ──AES-GCM──> [same key]
```

The wrapping lives in `vault_meta.json`. It holds no secret — only salts, Argon2id
settings and the sealed key. **That file can travel.** Copy it to a second device, type
the same passcode, and the key unwraps there. No key escrow, no server, no QR pairing.

This is the piece that usually forces password managers to run a service. We don't need
one.

What we do *not* have: any notion of when an entry changed, of a deleted entry, or of
which device wrote what. The schema is `login_entries(id, title, username, password,
website, totpSecret)` and nothing else. Merging is impossible with that alone.

## 2. Goals and non-goals

**Goals**

- Two or more devices converge on the same vault contents.
- The storage provider only ever sees ciphertext.
- Works with storage the user already has and controls.
- An interrupted or half-finished sync never destroys data.
- A user who stops syncing keeps a working local vault.

**Non-goals for the first version**

- Real-time sync. Minutes of delay are fine.
- Sharing a credential with another person (that is its own roadmap item).
- Web. `sqflite` has no web support.
- A project-operated server of any kind.

## 3. Three problems, in order of difficulty

### 3.1 A live SQLite file must not be the synced artefact

This is the mistake that eats vaults. File-sync clients copy a file whenever it changes,
including part-way through a write. SQLite (and SQLCipher) write in pages, with a
journal or WAL alongside. Sync clients:

- copy `logins.db` mid-transaction and store a torn page;
- do not understand that `logins.db-wal` and `logins.db-journal` must move together with it;
- resolve two changed copies by inventing `logins (conflicted copy).db`, which the app never looks at.

So whatever we upload has to be a **consistent, self-contained artefact produced
deliberately**, never the file the app has open. SQLCipher can produce one:
`sqlcipher_export` into a fresh database, or `VACUUM INTO`, both of which write a clean
copy while the vault stays open.

### 3.2 Merging needs per-entry history

Today two devices cannot be reconciled: whoever writes last wins the entire vault, and
a deletion is indistinguishable from an entry that hasn't arrived yet. The minimum the
schema needs:

| Column | Why |
|---|---|
| `updatedAt` (UTC millis) | Decide which side of an edit is newer |
| `deletedAt` (nullable) | A **tombstone**: without it, a deleted entry comes back from the other device |
| `revision` (int) | Cheap change detection, and a tiebreak when clocks are equal |
| `deviceId` | Tiebreak when two devices write in the same millisecond, and useful in logs |

Plus, once per vault: a `vaultId` (UUID, in `vault_meta.json`) so the app can refuse to
merge two *different* vaults that happen to share a passcode.

Tombstones need a retention policy — keep them, say, 90 days, then purge — or the vault
grows forever. Purging too early resurrects deleted entries from a device that was
offline longer than the retention window.

**Clocks are not trustworthy.** Device clocks drift and users change them. Last-writer-wins
by wall clock is the pragmatic choice, but it is wrong when a device's clock is wrong. A
Lamport counter per entry (`revision`) ordered by `(revision, updatedAt, deviceId)` is
strictly better and barely more work.

### 3.3 Bring-your-own-storage does not require provider SDKs

Worth stating plainly, because it changes the size of this project:

- **Desktop:** iCloud Drive, Dropbox, Google Drive and OneDrive are *ordinary folders*. The user picks one; their own client syncs it.
- **iOS:** the document picker returns a security-scoped URL, including iCloud Drive and any installed provider.
- **Android:** the storage access framework returns a tree URI, including Drive, OneDrive and Nextcloud.

So one **folder-shaped interface** — list, read, write, delete — covers most of the
promise with no OAuth client, no consent screen, no API keys and no per-provider code.
Provider APIs (Drive REST, S3, WebDAV) can come later behind the same interface, and
buy mainly better conflict detection through server-side revision ids.

## 4. Design decisions

### OPEN 1 — What is the unit of sync?

**Option A: one small encrypted file per entry** *(recommended)*

```
vault/
  meta.json              wrapped keys, vaultId, format version
  items/<uuid>.bin       one entry, AES-GCM under the vault key
  items/<uuid>.bin
```

- Two devices editing *different* entries never conflict at all.
- Small immutable files are what sync clients handle best.
- Recovering from a partial sync is trivial: missing files are simply missing entries.
- **Cost:** the number of entries and their ids are visible to the provider, as are file timestamps. Contents and titles are not.

**Option B: one encrypted snapshot of the whole vault**

```
vault/
  meta.json
  vault-<timestamp>.bin  entire vault, sealed
```

- Leaks nothing but the vault's size and when you use it.
- **Cost:** any two offline edits conflict over the *whole vault*, and resolving means choosing one device's version and discarding the other's. For a password manager that means silently losing a password someone just saved.

A hybrid is possible — per-entry files plus a periodic sealed snapshot for backup — and
is probably where this ends up, but the first version should pick one.

### OPEN 2 — Which storage first?

**Recommended:** a folder the user picks (§3.3), with the provider's own client doing
the syncing. It reaches desktop and mobile through OS pickers, needs no credentials, and
keeps the "your storage, your account" promise literally true.

**Alternative:** implement Google Drive's API first. Better conflict detection and
identical behaviour everywhere, at the cost of an OAuth client, a verification review,
and a new integration for every provider after it.

### OPEN 3 — What triggers a sync?

**Recommended for v1:** a manual **Sync now** in the settings drawer — which is what the
placeholder `ICloud` item at `lib/screens/setting-drawer.dart:74` should become — plus a
visible "last synced" time and an obvious error state. While the merge code is new,
silent background sync turns merge bugs into silent data loss.

**Later:** sync on unlock, after an edit, and periodically.

## 5. Proposed shape, if the recommendations are taken

**Remote layout**

```
<chosen folder>/
  meta.json                    wrapped keys, vaultId, format version
  items/<uuid>.bin             AES-GCM: nonce | ciphertext | tag
  tombstones/<uuid>.bin        deletions, retained 90 days
```

`meta.json` is written once and only changes when the passcode changes. Every other file
is immutable once written: an edit writes a new file and replaces it atomically.

**Write protocol (every file, every platform)**

1. Write `<name>.tmp`.
2. `fsync`.
3. Rename over the target — atomic on every filesystem we support.

Never edit in place. A crash leaves either the old file or the new one, never half of each.

**Sync algorithm (one pass)**

1. Read the remote `meta.json`. If `vaultId` differs from the local one, stop and ask: this is a different vault, not a conflict.
2. List remote items and compare `(revision, updatedAt, deviceId)` per id against local.
3. For each id: remote newer → decrypt, verify, apply locally. Local newer → upload. Equal → skip.
4. Tombstones beat entries of the same or older revision.
5. Apply everything inside one local transaction, so a failure mid-merge changes nothing.
6. Record `lastSyncedAt` and per-item revisions.

**True conflicts** — the same entry edited on two devices since the last sync — are rare
with per-entry files, and must never be resolved silently. Keep both: the loser becomes
a new entry titled `GitHub (conflicted copy from Pixel, 3 Oct 14:02)`, so nothing is
lost and the user decides.

**Schema changes** (`login_entries`): `updatedAt`, `deletedAt`, `revision`, `deviceId`,
all under a schema v4 migration. `deviceId` and `vaultId` go in `vault_meta.json`.

## 6. Threat model, once the vault leaves the device

What the provider (and anyone who compromises that account) sees:

| Sees | Does not see |
|---|---|
| The vault exists, and its `vaultId` | Any password, username, title, URL or TOTP secret |
| How many entries there are, and their ids (Option A) | Which sites you have accounts with |
| When each entry was last changed | The passcode, the recovery answer, or the vault key |
| Argon2id salts and settings | Anything that shortens an offline attack, beyond the passcode's own strength |

Consequences worth being explicit about, in the README as well as here:

- **The passcode becomes the whole defence.** Locally, an attacker needs the device *and* the passcode. Once ciphertext sits in cloud storage, a weak passcode can be attacked offline, at Argon2id cost per guess, by anyone who gets that account. Turning on sync is the moment to require a stronger passcode and to push #37 (hardware-backed quick unlock) and #38 (recovery key).
- **Deletion is not deletion.** Providers keep version history and trash. An entry removed today may live on in the user's own Drive history for weeks. Say so.
- **A tampered file must never be trusted.** AES-GCM already fails closed on modified ciphertext; the app must treat that as an error to surface, not a file to skip quietly.
- **Rollback is possible.** Someone with write access to the folder can restore an old file and revive an old password. Signing the item index with a key derived from the vault key mitigates it; worth considering, not necessarily in v1.

## 7. What could still go wrong

- **Two devices, same second, same entry.** Handled by `(revision, updatedAt, deviceId)` and, failing that, a conflicted copy.
- **The user changes the passcode on device A.** `meta.json` is rewrapped; device B still has the old wrapping and keeps working locally, but must re-read `meta.json` before it can sync again. The database key itself never changes, so the entries stay readable — a direct benefit of not deriving the key from the passcode.
- **The user restores an old folder from backup.** Old revisions lose to newer local ones, so the vault heals; tombstones stop deleted entries returning, until they are purged.
- **The folder is gone or unreadable** (unmounted, permission revoked, provider signed out). Sync must fail visibly and never treat "no remote items" as "everything was deleted" — that mistake would wipe the vault.
- **Storage is full or the file is locked** mid-write. The temp-file-and-rename protocol leaves the old state intact.

## 8. Suggested phases

Each becomes its own work item. Every phase ships something testable, and nothing
touches the user's data until phase 4.

1. **Change tracking.** Schema v4 with `updatedAt`, `deletedAt`, `revision`, `deviceId`; soft delete; `vaultId` in `vault_meta.json`. No sync, no UI. Unit-testable in full.
2. **Merge engine.** Pure Dart, no I/O: given local and remote item metadata, decide apply / upload / skip / conflict. This is where the data loss lives, so it gets the heaviest tests, including property tests for convergence.
3. **Sync bundle format.** Encrypt and decrypt an item file; the atomic write protocol; `meta.json` versioning; integrity failures surfaced as errors.
4. **Folder backend and Sync now.** The OS pickers, the settings drawer item that replaces the `ICloud` placeholder, the last-synced state and error reporting.
5. **Conflicted copies and tombstone purging.**
6. **Automatic sync**, once the rest has proven itself.
7. *(Optional)* **Provider APIs** behind the same interface, if folder sync proves insufficient.

## 9. Questions for discussion

1. Is the per-entry-file leak (entry count and ids visible to the provider) acceptable, or does that alone decide it for whole-vault snapshots?
2. Should turning on sync **require** a stronger passcode, given §6? If so, what rule — and what happens to a user whose existing passcode is four digits?
3. Should sync be per-device opt-in, or does enabling it on one device enable it everywhere?
4. How long should tombstones live? 90 days assumes no device stays offline longer than that.
5. Is a conflicted-copy entry the right answer, or should the app offer a proper side-by-side resolution screen?
6. Does the first version need to work on mobile, or is desktop enough to prove the design?
