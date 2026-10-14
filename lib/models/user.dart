class User {
  final String id;
  final String username;
  final String email;
  final String password;
  final String? fullName;
  final String? phone;
  final String? roleId;
  final List<String> permissionIds;
  final Map<String, Map<String, bool>> routePermissions;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.password = '',
    this.fullName,
    this.phone,
    this.roleId,
    this.permissionIds = const [],
    this.routePermissions = const {},
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'password': password,
      'fullName': fullName,
      'phone': phone,
      'roleId': roleId,
      'permissionIds': permissionIds,
      'routePermissions': routePermissions,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    try {
      bool parseBool(dynamic v) {
        if (v == null) return false;
        if (v is bool) return v;
        if (v is int) return v == 1;
        if (v is String) {
          return v == '1' || v.toLowerCase() == 'true';
        }
        return false;
      }

      final routePermissions = <String, Map<String, bool>>{};
      try {
        final rpRaw = json['routePermissions'];
        if (rpRaw is Map<String, dynamic>) {
          rpRaw.forEach((route, perms) {
            if (perms is Map<String, dynamic>) {
              final permMap = <String, bool>{};
              perms.forEach((key, value) {
                permMap[key] = parseBool(value);
              });
              routePermissions[route] = permMap;
            }
          });
        }
      } catch (e) {
        rethrow;
      }

      return User(
        id: json['id']?.toString() ?? '',
        username: json['username']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        password: json['password']?.toString() ?? '',
        fullName: json['fullName']?.toString(),
        phone: json['phone']?.toString(),
        roleId: json['roleId']?.toString(),
        permissionIds: (json['permissionIds'] is List)
            ? List<String>.from(
                json['permissionIds'].map((e) => e?.toString() ?? ''),
              )
            : [],
        routePermissions: routePermissions,
        isActive: parseBool(json['isActive']),
        createdAt:
            DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'].toString())
            : null,
      );
    } catch (e) {
      rethrow;
    }
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? password,
    String? fullName,
    String? phone,
    String? roleId,
    List<String>? permissionIds,
    Map<String, Map<String, bool>>? routePermissions,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      roleId: roleId ?? this.roleId,
      permissionIds: permissionIds ?? this.permissionIds,
      routePermissions: routePermissions ?? this.routePermissions,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
