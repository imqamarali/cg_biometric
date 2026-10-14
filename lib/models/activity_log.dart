class ActivityLog {
  final String id;
  final String userId;
  final String? userName;
  final String module; // e.g., 'Users & Access Control', 'Inventory Management'
  final String action; // e.g., 'Created', 'Updated', 'Deleted', 'Viewed'
  final String entityType; // e.g., 'User', 'Role', 'Product', 'Category'
  final String? entityId;
  final String? entityName;
  final String? details; // Additional details about the action
  final Map<String, dynamic>? changes; // For update actions, store what changed
  final String? ipAddress;
  final DateTime timestamp;

  ActivityLog({
    required this.id,
    required this.userId,
    this.userName,
    required this.module,
    required this.action,
    required this.entityType,
    this.entityId,
    this.entityName,
    this.details,
    this.changes,
    this.ipAddress,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'module': module,
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
      'entityName': entityName,
      'details': details,
      'changes': changes,
      'ipAddress': ipAddress,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    try {
      return ActivityLog(
        id: json['id']?.toString() ?? '',
        userId: json['userId']?.toString() ?? '',
        userName: json['userName']?.toString(),
        module: json['module']?.toString() ?? '',
        action: json['action']?.toString() ?? '',
        entityType: json['entityType']?.toString() ?? '',
        entityId: json['entityId']?.toString(),
        entityName: json['entityName']?.toString(),
        details: json['details']?.toString(),
        changes: json['changes'] != null
            ? Map<String, dynamic>.from(json['changes'] as Map)
            : null,
        ipAddress: json['ipAddress']?.toString(),
        timestamp:
            DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
            DateTime.now(),
      );
    } catch (e) {
      rethrow;
    }
  }

  ActivityLog copyWith({
    String? id,
    String? userId,
    String? userName,
    String? module,
    String? action,
    String? entityType,
    String? entityId,
    String? entityName,
    String? details,
    Map<String, dynamic>? changes,
    String? ipAddress,
    DateTime? timestamp,
  }) {
    return ActivityLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      module: module ?? this.module,
      action: action ?? this.action,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      entityName: entityName ?? this.entityName,
      details: details ?? this.details,
      changes: changes ?? this.changes,
      ipAddress: ipAddress ?? this.ipAddress,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
