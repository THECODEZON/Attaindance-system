class Student {
  final String uid;
  final String name;
  final String email;
  final String photoUrl;
  final String regNo;
  final String section;
  final double cgpa;
  final String address;
  final String phone;
  final int lastUpdated;
  final String role; // 'student' or 'admin'

  Student({
    required this.uid,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.regNo,
    required this.section,
    required this.cgpa,
    required this.address,
    required this.phone,
    this.lastUpdated = 0,
    this.role = 'student',
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'regNo': regNo,
      'section': section,
      'cgpa': cgpa,
      'address': address,
      'phone': phone,
      'lastUpdated': lastUpdated,
      'role': role,
    };
  }

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      uid: map['uid'] ?? '',
      name: map['name'] ?? 'Student',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'] ?? 'https://api.dicebear.com/7.x/initials/png?seed=Student&backgroundColor=fb8c00',
      regNo: map['regNo'] ?? 'Unknown',
      section: map['section'] ?? 'N/A',
      cgpa: (map['cgpa'] ?? 0.0).toDouble(),
      address: map['address'] ?? 'No Address Provided',
      phone: map['phone'] ?? 'No Phone Provided',
      lastUpdated: map['lastUpdated'] ?? 0,
      role: map['role'] ?? 'student',
    );
  }

  factory Student.mock() {
    return Student(
      uid: "mock_uid",
      name: "Deepa Das",
      email: "ddas12181@gmail.com",
      photoUrl: "https://api.dicebear.com/7.x/initials/png?seed=Deepa&backgroundColor=fb8c00",
      regNo: "12181056",
      section: "K21PD",
      cgpa: 8.75,
      address: "Jalandhar Cantt, Punjab, India",
      phone: "+91 77078 87151",
      lastUpdated: DateTime.now().millisecondsSinceEpoch,
      role: 'student',
    );
  }

  Student copyWith({
    String? uid,
    String? name,
    String? email,
    String? photoUrl,
    String? regNo,
    String? section,
    double? cgpa,
    String? address,
    String? phone,
    int? lastUpdated,
    String? role,
  }) {
    return Student(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      regNo: regNo ?? this.regNo,
      section: section ?? this.section,
      cgpa: cgpa ?? this.cgpa,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      role: role ?? this.role,
    );
  }
}
