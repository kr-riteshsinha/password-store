/// The vault's single profile.
///
/// It holds only what is safe to keep inside the vault: an id and the display
/// name. The passcode and recovery answer are not stored anywhere — they wrap
/// the database key in `vault_meta.json` — and the recovery question lives
/// there too, since it must be readable before the vault is unlocked.
class ProfileEntry {
  final String id;
  final String name;

  ProfileEntry({
    required this.id,
    required this.name,
  });

  factory ProfileEntry.fromMap(Map<String, dynamic> map) {
    return ProfileEntry(
      id: map['id'],
      name: map['name'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  ProfileEntry copyWith({
    String? id,
    String? name,
  }) {
    return ProfileEntry(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }
}
