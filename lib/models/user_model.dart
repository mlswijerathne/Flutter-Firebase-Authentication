class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? profilePicture;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.profilePicture,
  });

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      profilePicture: data['profilePicture'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'profilePicture': profilePicture,
    };
  }
}