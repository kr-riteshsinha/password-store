class LoginEntry {
  final String id;
  final String title;
  final String username;
  final String password;
  final String website;
  final String? totpSecret;

  LoginEntry({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    required this.website,
    this.totpSecret,
  });

  factory LoginEntry.fromMap(Map<String, dynamic> map) {
    return LoginEntry(
      id: map['id'],
      title: map['title'],
      username: map['username'],
      password: map['password'],
      website: map['website'],
      totpSecret: map['totpSecret'],
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
    };
  }
}
