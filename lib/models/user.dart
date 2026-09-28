/// 👤 مۆدێلی بەکارهێنەر
class AppUser {
  final String? id;
  final String? name;
  final String? phone;
  final String? password;
  final String role; // customer, vendor, admin
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

  /// دروستکردن لە JSON
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

  /// گۆڕین بۆ JSON
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'password': password,
      'role': role,
      'is_approved': isApproved,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// کۆپی لەگەڵ گۆڕانکاری
  AppUser copyWith({
    String? id,
    String? name,
    String? phone,
    String? role,
    bool? isApproved,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      password: password,
      role: role ?? this.role,
      isApproved: isApproved ?? this.isApproved,
      createdAt: createdAt,
    );
  }

  // ڕۆڵەکان
  bool get isAdmin => role == 'admin';
  bool get isVendor => role == 'vendor' || isAdmin;
  bool get isCustomer => role == 'customer';
}