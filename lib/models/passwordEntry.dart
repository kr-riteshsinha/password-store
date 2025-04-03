class PasswordEntry {
  int? id;
  String username;
  String password;
  String category;
  String expiryDate;
  String? url;
  bool isFavorite ;

  PasswordEntry({
    this.id,
    required this.username,
    required this.password,
    required this.category,
    required this.expiryDate,
    this.url,
    this.isFavorite = false
});
  // Convert Object to Map (for database)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'category': category,
      'expiryDate': expiryDate,
      'url':url,
      'isFavorite': isFavorite ? 1 : 0
    };
  }

  // Convert Map to Object
  factory PasswordEntry.fromMap(Map<String, dynamic> map) {
    return PasswordEntry(
      id: map['id'],
      username: map['username'],
      password: map['password'],
      category: map['category'],
      expiryDate: map['expiryDate'],
      isFavorite: map['isFavorite'] == 1
    );
  }

}
