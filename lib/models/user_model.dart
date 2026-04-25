class AppUser {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;

  AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'],
      photoUrl: map['photoUrl'],
    );
  }
}
