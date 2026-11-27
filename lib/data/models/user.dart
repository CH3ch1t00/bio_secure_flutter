class BioUser {
  final String uid;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String? image;
  final String role; // admin | employee
  final String cargo;
  final String department;
  final String companyId;
  final String? fcmToken;
  final bool isActive;
  final String? shiftId;
  final String? sedeId;

  BioUser({
    required this.uid,
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.phone = '',
    this.image,
    this.role = 'employee',
    this.cargo = '',
    this.department = '',
    this.companyId = '',
    this.fcmToken,
    this.isActive = true,
    this.shiftId,
    this.sedeId,
  });

  bool get isAdmin => role.trim().toLowerCase() == 'admin';

  String get fullName {
    final joined = ('$firstName $lastName').trim();
    if (joined.isNotEmpty) return joined;
    return email.split('@').first;
  }

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory BioUser.fromMap(String uid, Map<String, dynamic> m) {
    // El backend Android original guarda el nombre completo en `name`.
    final rawName = (m['name'] as String?)?.trim() ?? '';
    var first = (m['firstName'] as String?)?.trim() ?? '';
    var last = (m['lastName'] as String?)?.trim() ?? '';

    if (first.isEmpty && rawName.isNotEmpty) {
      final parts = rawName.split(RegExp(r'\s+'));
      first = parts.first;
      last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }

    final rawRole = (m['role'] as String?)?.trim().toLowerCase() ?? 'employee';

    return BioUser(
      uid: uid,
      firstName: first,
      lastName: last,
      email: (m['email'] as String?)?.trim() ?? '',
      phone: (m['phone'] as String?)?.trim() ?? '',
      image: (m['image'] as String?)?.nullIfEmpty,
      role: rawRole.isEmpty ? 'employee' : rawRole,
      cargo: m['cargo'] ?? '',
      department: m['department'] ?? '',
      companyId: (m['companyId'] as String?)?.trim() ?? '',
      fcmToken: m['fcmToken'],
      isActive: m['isActive'] ?? true,
      shiftId: (m['shiftId'] as String?)?.nullIfEmpty,
      sedeId: (m['sedeId'] as String?)?.nullIfEmpty,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': fullName,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'image': image,
        'role': role,
        'cargo': cargo,
        'department': department,
        'companyId': companyId,
        'fcmToken': fcmToken,
        'isActive': isActive,
        'shiftId': shiftId ?? '',
        'sedeId': sedeId ?? '',
      };

  BioUser copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? image,
    String? role,
    String? cargo,
    String? department,
    String? companyId,
    String? fcmToken,
    bool? isActive,
    String? shiftId,
    String? sedeId,
  }) =>
      BioUser(
        uid: uid,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        image: image ?? this.image,
        role: role ?? this.role,
        cargo: cargo ?? this.cargo,
        department: department ?? this.department,
        companyId: companyId ?? this.companyId,
        fcmToken: fcmToken ?? this.fcmToken,
        isActive: isActive ?? this.isActive,
        shiftId: shiftId ?? this.shiftId,
        sedeId: sedeId ?? this.sedeId,
      );
}

extension _NullIfEmpty on String {
  String? get nullIfEmpty {
    final t = trim();
    return t.isEmpty ? null : t;
  }
}
