class ProfileEntry {
  final String id;
  final String name;
  final String password;
  final String hint;
  final String answer;

  ProfileEntry({
    required this.id,
    required this.name,
    required this.password,
    required this.hint,
    required this.answer,

  });

  factory ProfileEntry.fromMap(Map<String, dynamic> map) {
    return ProfileEntry(
      id: map['id'],
      name: map['name'],
      password: map['password'],
      hint: map['hint'],
      answer: map['answer']
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'password': password,
      'hint': hint,
      'answer' :answer
    };
  }

  ProfileEntry copyWith({
    String? id,
    String? name,
    String? password,
    String? hint,
    String? answer,
  }) {
    return ProfileEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      password: password ?? this.password,
      hint: hint ?? this.hint,
      answer: answer ?? this.answer,
    );
  }
}
