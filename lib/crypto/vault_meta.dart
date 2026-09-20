import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'vault_keys.dart';

/// Everything needed to unlock the vault, except what the user knows.
///
/// It sits next to `logins.db` as `vault_meta.json`, outside the encrypted
/// database — it has to be readable before the database can be opened. It
/// holds no secret: only salts, Argon2id settings and the database key sealed
/// with AES-GCM, once per unlock method.
class VaultMeta {
  /// Format version of this file, not the database schema version.
  static const currentVersion = 1;

  final int version;
  final KdfParams passcodeKdf;
  final WrappedKey passcodeWrap;

  /// Present when recovery is set up, so a forgotten passcode can be reset
  /// without losing the vault.
  final KdfParams? recoveryKdf;
  final WrappedKey? recoveryWrap;

  /// The recovery question, in the clear.
  ///
  /// It has to be readable before the vault is unlocked, since it is what the
  /// user is shown when they have forgotten the passcode. It is a prompt, not
  /// a secret — but pick a question that gives nothing away, because anyone
  /// with the file can read it.
  final String? recoveryQuestion;

  const VaultMeta({
    this.version = currentVersion,
    required this.passcodeKdf,
    required this.passcodeWrap,
    this.recoveryKdf,
    this.recoveryWrap,
    this.recoveryQuestion,
  });

  bool get hasRecovery => recoveryKdf != null && recoveryWrap != null;

  VaultMeta copyWith({
    KdfParams? passcodeKdf,
    WrappedKey? passcodeWrap,
    KdfParams? recoveryKdf,
    WrappedKey? recoveryWrap,
    String? recoveryQuestion,
  }) =>
      VaultMeta(
        version: version,
        passcodeKdf: passcodeKdf ?? this.passcodeKdf,
        passcodeWrap: passcodeWrap ?? this.passcodeWrap,
        recoveryKdf: recoveryKdf ?? this.recoveryKdf,
        recoveryWrap: recoveryWrap ?? this.recoveryWrap,
        recoveryQuestion: recoveryQuestion ?? this.recoveryQuestion,
      );

  Map<String, dynamic> toJson() => {
        'version': version,
        'passcodeKdf': passcodeKdf.toJson(),
        'passcodeWrap': passcodeWrap.toJson(),
        if (recoveryKdf != null) 'recoveryKdf': recoveryKdf!.toJson(),
        if (recoveryWrap != null) 'recoveryWrap': recoveryWrap!.toJson(),
        if (recoveryQuestion != null) 'recoveryQuestion': recoveryQuestion,
      };

  factory VaultMeta.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as int;
    if (version > currentVersion) {
      throw const VaultMetaException(
        'This vault was created by a newer version of the app.',
      );
    }
    final recoveryKdf = json['recoveryKdf'];
    final recoveryWrap = json['recoveryWrap'];
    return VaultMeta(
      version: version,
      passcodeKdf: KdfParams.fromJson(json['passcodeKdf'] as Map<String, dynamic>),
      passcodeWrap: WrappedKey.fromJson(json['passcodeWrap'] as Map<String, dynamic>),
      recoveryKdf: recoveryKdf == null
          ? null
          : KdfParams.fromJson(recoveryKdf as Map<String, dynamic>),
      recoveryWrap: recoveryWrap == null
          ? null
          : WrappedKey.fromJson(recoveryWrap as Map<String, dynamic>),
      recoveryQuestion: json['recoveryQuestion'] as String?,
    );
  }
}

class VaultMetaException implements Exception {
  final String message;
  const VaultMetaException(this.message);
  @override
  String toString() => message;
}

/// Reads and writes `vault_meta.json`.
class VaultMetaStore {
  static const fileName = 'vault_meta.json';

  /// Directory holding the database, from `getDatabasesPath()`.
  final String directory;

  const VaultMetaStore(this.directory);

  File get file => File('$directory/$fileName');

  Future<bool> exists() => file.exists();

  /// The stored metadata, or null when no encrypted vault exists yet.
  Future<VaultMeta?> read() async {
    if (!await file.exists()) return null;
    final text = await file.readAsString();
    try {
      return VaultMeta.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } on VaultMetaException {
      rethrow;
    } catch (e) {
      throw VaultMetaException('$fileName is unreadable: $e');
    }
  }

  /// Writes the metadata, replacing a temporary file into place so a crash
  /// midway can't leave a half-written file that locks the vault.
  Future<void> write(VaultMeta meta) async {
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(meta.toJson()),
      flush: true,
    );
    await temp.rename(file.path);
  }
}

/// Builds the metadata for a brand-new vault and returns it with the database
/// key it seals, so the caller can open the database straight away.
class NewVaultKeys {
  final VaultMeta meta;
  final Uint8List databaseKey;

  const NewVaultKeys(this.meta, this.databaseKey);
}

/// Creates the keys for a new vault. The recovery answer gets its own salt and
/// its own wrapping of the same database key.
Future<NewVaultKeys> createVaultKeys({
  required String passcode,
  String? recoveryAnswer,
  String? recoveryQuestion,
  KdfParams Function() newParams = KdfParams.generate,
}) async {
  final databaseKey = VaultKeys.newDatabaseKey();

  final passcodeKdf = newParams();
  final passcodeWrap = await VaultKeys.wrap(
    databaseKey,
    VaultKeys.deriveKek(passcode, passcodeKdf),
  );

  KdfParams? recoveryKdf;
  WrappedKey? recoveryWrap;
  if (recoveryAnswer != null && recoveryAnswer.trim().isNotEmpty) {
    recoveryKdf = newParams();
    recoveryWrap = await VaultKeys.wrap(
      databaseKey,
      VaultKeys.deriveKek(normalizeAnswer(recoveryAnswer), recoveryKdf),
    );
  }

  return NewVaultKeys(
    VaultMeta(
      passcodeKdf: passcodeKdf,
      passcodeWrap: passcodeWrap,
      recoveryKdf: recoveryKdf,
      recoveryWrap: recoveryWrap,
      recoveryQuestion: recoveryWrap == null ? null : recoveryQuestion?.trim(),
    ),
    databaseKey,
  );
}

/// Recovery answers are compared ignoring case and surrounding spaces, so the
/// key has to be derived from the same normalised form.
String normalizeAnswer(String answer) => answer.trim().toLowerCase();

/// Unlocks with the passcode, or returns null if it is wrong.
Future<Uint8List?> unlockWithPasscode(VaultMeta meta, String passcode) =>
    VaultKeys.unwrap(meta.passcodeWrap, VaultKeys.deriveKek(passcode, meta.passcodeKdf));

/// Unlocks with the recovery answer, or returns null if it is wrong or
/// recovery was never set up.
Future<Uint8List?> unlockWithRecoveryAnswer(VaultMeta meta, String answer) async {
  if (!meta.hasRecovery) return null;
  if (answer.trim().isEmpty) return null;
  return VaultKeys.unwrap(
    meta.recoveryWrap!,
    VaultKeys.deriveKek(normalizeAnswer(answer), meta.recoveryKdf!),
  );
}

/// Seals the same database key under a new passcode. The vault itself is not
/// touched, so changing the passcode is instant however large the vault is.
Future<VaultMeta> rewrapWithPasscode(
  VaultMeta meta,
  Uint8List databaseKey,
  String newPasscode, {
  KdfParams Function() newParams = KdfParams.generate,
}) async {
  final kdf = newParams();
  return meta.copyWith(
    passcodeKdf: kdf,
    passcodeWrap: await VaultKeys.wrap(
      databaseKey,
      VaultKeys.deriveKek(newPasscode, kdf),
    ),
  );
}
