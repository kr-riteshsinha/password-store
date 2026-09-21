/// A saved login.
///
/// Besides the fields the user sees, every entry carries the history that
/// backup and merging need (`docs/sync-design.md` §3.2): when it last changed,
/// how many times it has changed, which device changed it, and whether it has
/// been deleted.
class LoginEntry {
  final String id;
  final String title;
  final String username;
  final String password;
  final String website;
  final String? totpSecret;

  /// When this entry last changed, in UTC milliseconds.
  final int updatedAt;

  /// When this entry was deleted, in UTC milliseconds, or null while it
  /// exists. A deleted entry keeps its row as a **tombstone**: without one,
  /// another device would simply put the entry back.
  final int? deletedAt;

  /// Counts changes to this entry. Compared before [updatedAt], so a device
  /// with a wrong clock cannot silently win.
  final int revision;

  /// The device that last changed this entry. Breaks ties when two devices
  /// write in the same millisecond, and helps when reading logs.
  final String deviceId;

  LoginEntry({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    required this.website,
    this.totpSecret,
    this.updatedAt = 0,
    this.deletedAt,
    this.revision = 1,
    this.deviceId = '',
  });

  /// Whether this row is a tombstone rather than a live entry.
  bool get isDeleted => deletedAt != null;

  factory LoginEntry.fromMap(Map<String, dynamic> map) {
    return LoginEntry(
      id: map['id'],
      title: map['title'],
      username: map['username'],
      password: map['password'],
      website: map['website'],
      totpSecret: map['totpSecret'],
      updatedAt: map['updatedAt'] as int? ?? 0,
      deletedAt: map['deletedAt'] as int?,
      revision: map['revision'] as int? ?? 1,
      deviceId: map['deviceId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'username': username,
      'password': password,
      'website': website,
      'totpSecret': totpSecret,
      'updatedAt': updatedAt,
      'deletedAt': deletedAt,
      'revision': revision,
      'deviceId': deviceId,
    };
  }

  /// Marks "not given" for the nullable fields, so passing null can mean
  /// *clear this* — which is what un-deleting an entry or removing a TOTP
  /// secret needs.
  static const _unset = Object();

  LoginEntry copyWith({
    String? id,
    String? title,
    String? username,
    String? password,
    String? website,
    Object? totpSecret = _unset,
    int? updatedAt,
    Object? deletedAt = _unset,
    int? revision,
    String? deviceId,
  }) {
    return LoginEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      website: website ?? this.website,
      totpSecret:
          identical(totpSecret, _unset) ? this.totpSecret : totpSecret as String?,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt:
          identical(deletedAt, _unset) ? this.deletedAt : deletedAt as int?,
      revision: revision ?? this.revision,
      deviceId: deviceId ?? this.deviceId,
    );
  }
}
