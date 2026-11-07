// lib/models/user.dart

/// 👤 مۆدێلی بەکارهێنەر
class AppUser {
  final String? id;
  final String? name;
  final String? phone;
  final String? password;
  final String role;
  final bool isApproved;
  final DateTime? createdAt;

  AppUser({
    this.id,
    this.name,
    this.phone,
    this.password,
    this.role = 'customer',
    this.isApproved = false,
    this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id']?.toString(),
      name: json['name']?.toString(),
      phone: json['phone']?.toString(),
      password: json['password']?.toString(),
      role: json['role']?.toString() ?? 'customer',
      isApproved: json['is_approved'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson({bool includeNullables = false}) {
    return {
      if (id != null) 'id': id,
      if (includeNullables || name != null) 'name': name,
      if (includeNullables || phone != null) 'phone': phone,
      if (includeNullables || password != null) 'password': password,
      'role': role,
      'is_approved': isApproved,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    final json = toJson(includeNullables: true);
    json['updated_at'] = DateTime.now().toUtc().toIso8601String();
    return json;
  }

  String get displayName {
    final n = name?.trim();
    return (n == null || n.isEmpty) ? (phone ?? 'بەکارهێنەر') : n;
  }

  AppUser copyWith({
    String? id, bool clearId = false,
    String? name, bool clearName = false,
    String? phone, bool clearPhone = false,
    String? password, bool clearPassword = false,
    String? role,
    bool? isApproved,
    DateTime? createdAt, bool clearCreatedAt = false,
  }) {
    return AppUser(
      id: clearId ? null : (id ?? this.id),
      name: clearName ? null : (name ?? this.name),
      phone: clearPhone ? null : (phone ?? this.phone),
      password: clearPassword ? null : (password ?? this.password),
      role: role ?? this.role,
      isApproved: isApproved ?? this.isApproved,
      createdAt: clearCreatedAt ? null : (createdAt ?? this.createdAt),
    );
  }

  bool get isAdmin => role == 'admin';
  bool get isVendor => role == 'vendor' || isAdmin;
  bool get isCustomer => role == 'customer';
}