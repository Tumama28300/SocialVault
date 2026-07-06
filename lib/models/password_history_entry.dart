class PasswordHistoryEntry {
  final String password;
  final DateTime savedAt;

  const PasswordHistoryEntry({required this.password, required this.savedAt});

  Map<String, dynamic> toJson() => {
    'password': password,
    'savedAt': savedAt.toIso8601String(),
  };

  factory PasswordHistoryEntry.fromJson(Map<String, dynamic> json) {
    return PasswordHistoryEntry(
      password: json['password'] as String,
      savedAt: DateTime.parse(json['savedAt'] as String),
    );
  }
}
