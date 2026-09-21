# Bring-your-own-storage sync — design discussion

**Status:** draft for discussion. Nothing here is built.

**Direction agreed:** ship **encrypted backup and restore first**, with true multi-device
merging as the goal. The schema work that merging needs lands early, so moving from one
to the other is not a migration.

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

- The vault survives a lost or broken device, and a new device can pick it up (v1).
- Two or more devices converge on the same vault contents (v2).
- The storage provider only ever sees ciphertext.
- Works with storage the user already has and controls.
- An interrupted or half-finished sync never destroys data.
- A user who stops syncing keeps a working local vault.

**Non-goals for the first version**

- Editing on two devices at once. v1 has a single writer; the rest restore.
- Real-time sync. A day of delay is the v1 default.
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
| *(fields cleared)* | A tombstone keeps **only the id and the timestamps**. Title, username, website, password and TOTP secret are all cleared on delete — see DECIDED 7 |
| `revision` (int) | Cheap change detection, and a tiebreak when clocks are equal |
| `deviceId` | Tiebreak when two devices write in the same millisecond, and useful in logs |

Plus, once per vault: a `vaultId` (in `vault_meta.json`) so the app can refuse to merge
two *different* vaults that happen to share a passcode.

The `deviceId`, by contrast, is **per install and stays local** (in preferences, not in
`vault_meta.json`). That file travels with a backup, so a vault restored onto a second
device would otherwise claim to be the device that wrote it — and every tiebreak that
depends on `deviceId` would be wrong.

Tombstones need a retention policy — keep them, say, 90 days, then purge — or the vault
grows forever. Purging too early resurrects deleted entries from a device that was
offline longer than the retention window.

**Entries that predate change tracking** keep `updatedAt = 0` and `revision = 1`,
meaning "no history known". Stamping the upgrade time instead would give the same entry
a different timestamp on every device that upgraded it, so a merge would be decided by
who upgraded last rather than by any real edit.

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

### 3.4 "Connect once" looks different per provider

A single "enter your credentials" screen cannot work, because most providers do not
issue credentials to apps at all:

| Provider | How an app connects | What we store |
|---|---|---|
| iCloud Drive | The device's signed-in account, through an iCloud container entitlement or the document picker | Nothing |
| Google Drive, OneDrive, Dropbox | OAuth in a browser | A refresh token, in the OS keychain |
| S3-compatible, WebDAV, Nextcloud | Credentials, genuinely | Access key and secret, in the OS keychain |

**There is no API that takes an Apple ID and password**, and a screen that asked for one
would be phishing-shaped and rejected from the App Store. The same holds for a Google
password. Only the third row is a username-and-password box.

What is true for every row: connect once, then the app can reach the storage whenever it
likes, without asking again. Any secret we do hold goes in the OS keychain, never in the
vault and never in `vault_meta.json`.

## 4. Design decisions

### DECIDED 1 — Backup and restore first, merging later

**Version 1 uploads a whole-vault snapshot**, once a day, and other devices restore from
it. Version 2 moves to per-entry files and a real merge.

This is worth being blunt about: **whole-file upload is a backup, not sync.** With one
writing device it is perfectly safe. With two it loses data, and quietly:

> Phone adds a password at 09:00. Laptop uploads its own copy at 14:00, from before that.
> The phone's password is gone — no error, no conflict, no way back unless the provider
> kept an old version.

So v1 constrains the shape rather than pretending the problem away:

- **One device is the writer.** It uploads; the others do not.
- **The others restore**, explicitly, with a warning that local changes are replaced.
- **Handing the writer role over is a deliberate action**, so two devices never both upload.
- The UI calls it backup, never "sync", until merging exists.

What this buys immediately: the vault survives a lost laptop, and a new device can pick
it up. What it does not buy: editing on two devices. A password added on the phone
leaves the laptop stale until it restores.

**Why merging still shapes v1.** The per-entry history (§3.2) lands in phase 1, before
any of this. Entries carry `updatedAt`, `deletedAt`, `revision` and `deviceId` from the
start, and snapshots therefore contain them. When the merge engine arrives, existing
backups already hold everything it needs — no second migration, and no vault written by
v1 that v2 cannot reconcile.

### DECIDED 2 — A folder the user picks, first

The user chooses a directory their own client already syncs: iCloud Drive, Dropbox,
Google Drive, OneDrive, or a plain folder. Desktop gets a directory picker; iOS the
document picker; Android the storage access framework (§3.3). No OAuth, no API keys, no
server.

Provider APIs (Drive REST, S3, WebDAV) come later behind the same interface, for
platforms or providers where a folder is not enough — and that is where the credential
screen in §3.4 belongs.

### DECIDED 3 — Daily, plus a button

The writer uploads **once a day** automatically, and whenever the user taps **Back up
now**. Restore is always manual and always confirmed. The settings drawer shows the
folder, the last backup time and any error, in place of today's placeholder `ICloud`
item (`lib/screens/setting-drawer.dart:74`).

Automatic *merging* stays off until the merge engine has proven itself; a daily
one-directional upload from a single writer has no merge to get wrong.

## 5. Proposed shape

### 5.1 Version 1 — backup and restore

**Remote layout**

```
<chosen folder>/
  meta.json                  wrapped keys, vaultId, format version
  backups/
    vault-<timestamp>.bin    whole-vault snapshot, sealed
    vault-<timestamp>.bin    the last N kept, oldest pruned
  last-backup.json           timestamp and deviceId of the most recent upload
```

**Producing a snapshot.** Never upload `logins.db` itself (§3.1). The writer runs
**`sqlcipher_export`** into a temporary file while the vault stays open, seals that,
uploads it, then deletes the temporary copy.

Not `VACUUM INTO`: with SQLCipher that writes a **plaintext** database, so the whole
vault would exist unencrypted on disk for as long as the backup takes. `sqlcipher_export`
writes the copy encrypted with the same key throughout.

**A sealed snapshot is:**

```
"PVSNAP" | version (1 byte) | nonce (12) | ciphertext | tag (16)
```

The magic and version stay in the clear so the app can recognise a file, and refuse one
from a newer format, without the key. Everything else is AES-GCM under the vault key, so
a tampered or truncated snapshot fails to open rather than restoring something subtly
wrong.

**Writing a file, on every platform**

1. Write `<name>.tmp`
2. `fsync`
3. Rename over the target — atomic on every filesystem we support

A crash leaves either the old file or the new one, never half of each. Snapshots are
named by timestamp and never overwritten, so a failed upload cannot damage an earlier
backup.

**Daily upload (writer only)**

1. Check `meta.json`: if `vaultId` differs, stop — this folder holds a different vault.
2. Check `last-backup.json`: if the last upload came from another device, warn that two devices are backing up the same vault and that the older copy's edits will be lost. Upload anyway if the user confirms.
3. Export, seal, upload, prune to the last N snapshots.
4. Write `last-backup.json`, record the time locally, and show it in the drawer.

**Restore (any device, always manual)**

1. List snapshots, newest first, with their timestamps.
2. Warn plainly: *this replaces everything in the local vault*.
3. Download, verify the authentication tag, unwrap with the passcode, write to a temporary database, **open that copy and read from it**, then swap it in atomically.
4. A failed tag, a wrong passcode, or a file that opens but cannot be read aborts before anything local is touched — and leaves the user's vault open, not closed behind them.

Reading from the candidate matters: SQLite is lazy, so a file of noise can "open"
successfully and only fail later when something touches a page. Counting the rows forces
it to read the schema and the data.

**On two devices backing up the same vault:** this is the one situation a
snapshot-shaped backup cannot survive, and v1 handles it with a warning rather than
machinery. `last-backup.json` names the device that uploaded last, so a second device
can say plainly what is about to happen. There is deliberately **no writer-role handover
flow**: it would be several screens of state that merging (§5.2) deletes outright. The
caveat lives in the UI text until merging lands, and merging is the next phase after
backup, not the last.

### 5.2 Version 2 — merging

Per-entry files, alongside the snapshots rather than instead of them:

```
<chosen folder>/
  meta.json
  items/<uuid>.bin           one entry, AES-GCM under the vault key
  tombstones/<uuid>.bin      deletions, retained 90 days
  backups/vault-<ts>.bin     snapshots stay, as backup
```

Merge, one pass: compare `(revision, updatedAt, deviceId)` per id; remote newer applies
locally, local newer uploads, tombstones beat entries of the same or older revision, and
everything lands inside one local transaction. A true conflict — the same entry edited
on two devices — keeps both, the loser becoming
`GitHub (conflicted copy from Pixel, 3 Oct 14:02)`. Nothing is resolved silently.

Because phase 1 puts the history in the schema from the start, a v1 snapshot already
contains everything v2 needs: the first merge simply reads it.

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
- **Two devices both upload.** The one case backup cannot survive. `last-backup.json` names the device that uploaded last, so the second device warns before replacing the first one's snapshot. Merging (phase 4) removes the problem rather than managing it.
- **A stale device restores over newer work.** Restore is manual, warns plainly and names the snapshot's timestamp, so this is a choice rather than an accident.
- **The folder is gone or unreadable** (unmounted, permission revoked, provider signed out). Sync must fail visibly and never treat "no remote items" as "everything was deleted" — that mistake would wipe the vault.
- **Storage is full or the file is locked** mid-write. The temp-file-and-rename protocol leaves the old state intact.

## 8. Phases

Each becomes its own work item. Nothing touches the user's data until phase 3.

**Backup — the safety net, shipped first**

1. **Change tracking.** Schema v4: `updatedAt`, `deletedAt`, `revision`, `deviceId`; soft delete; `vaultId` in `vault_meta.json`, `deviceId` in local preferences. No sync, no UI. Lands first precisely so that backups already carry what merging will need.
2. **Snapshot bundle format.** `VACUUM INTO` export, AES-GCM sealing, format versioning, the temp-and-rename protocol, integrity failures surfaced as errors.
3. **Folder backend, backup and restore.** The OS pickers; the settings drawer item that replaces the `ICloud` placeholder; **Back up now**, the daily upload, restore-with-warning, last-backup time and error state. From here a lost device no longer means a lost vault.

**Merging — next, not last**

4. **Merge engine.** Pure Dart, no I/O, the heaviest tests in the project.
5. **Per-entry files** alongside snapshots, and the switch from restore to merge. The two-device warning from phase 3 goes away here.
6. **Conflicted copies and tombstone purging.**
7. **Automatic sync**, once merging has proven itself.
8. *(Optional)* **Provider APIs** behind the same interface — Drive, S3, WebDAV — which is where the credential screen of §3.4 belongs.

**Deliberately not a phase:** a writer-role handover flow. It would exist only while
merging is missing, and merging deletes it. A warning in phase 3 covers the same ground
for the one or two releases it matters.

## 9. Decisions and what is still open

### DECIDED 4 — Keep ten snapshots

The writer keeps the ten most recent snapshots and prunes the oldest. That is roughly
ten days of history at one upload a day, enough to recover from a mistake noticed within
a week or so, and small enough that the folder stays tidy. The provider's own version
history may extend this, but nothing depends on that.

### DECIDED 5 — Backup requires a passcode of at least 8 characters

§6 is the reason: on the device, an attacker needs the device *and* the passcode. Once
ciphertext sits in someone's cloud storage, the passcode is the only thing between an
attacker and the vault, and a four-digit one falls to an offline attack even at Argon2id
cost.

So:

- Turning backup on requires a passcode of **at least 8 characters**.
- A user whose passcode is shorter is asked to change it first, in the backup flow, and cannot enable backup until they do. Changing it only rewraps the key, so it is instant and touches no entries.
- The local minimum for a new vault stays at 4 for now (`lib/utils/passcode_rules.dart`). Raising it for everyone is a separate decision, and worth taking once quick unlock (#37) removes the daily cost of typing a long passcode.
- The requirement is checked when backup is enabled **and** re-checked if the passcode is later changed to something shorter: shortening it below 8 while backup is on must warn, and either block or turn backup off.

### DECIDED 6 — Desktop and mobile together in phase 3

Phase 3 ships the directory picker on desktop *and* the iOS document picker and Android
storage access framework. Mobile is where a lost device is most likely, so backup that
only works on a laptop misses the point. The extra work is the pickers and persisting a
security-scoped bookmark or tree URI across launches; everything behind the backend
interface is shared.

### DECIDED 7 — A tombstone keeps only the id and timestamps

Deleting clears every field the user typed, not just the password. A title such as
"Very Private Bank" or a website is itself a fact about them, and a deleted entry should
leave nothing for a backup to carry around: tombstones travel to the user's cloud
storage and can outlive the entry by the whole retention window.

The cost is that "restore a deleted entry" can never be built from a tombstone — only
from a snapshot taken before the deletion. That is the right trade: snapshots already
exist for exactly this, and they are the thing a user reaches for after a mistake.

### Still open

1. **What should a device that is not the writer show?** "Last restored" only, or a prompt when a newer snapshot appears in the folder?
2. **Restore granularity** — whole vault only, or eventually picking individual entries out of a snapshot?
3. **Tombstone retention** for merging: 90 days assumes no device stays offline longer than that.
