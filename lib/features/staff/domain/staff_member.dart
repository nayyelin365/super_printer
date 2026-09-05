/// Roles selectable for a staff member — restricted to what's actually
/// used in a kitchen/restaurant setting (not a free-text field), so the
/// roster stays consistent and filterable.
const kitchenStaffRoles = [
  'Manager',
  'Chef',
  'Sous Chef',
  'Line Cook',
  'Kitchen Helper',
  'Server',
  'Host',
  'Cashier',
  'Dishwasher',
  'Delivery Driver',
];

/// A staff member selectable when recording who handled a step of a
/// procedure (e.g. the Sushi Rice SOP's "who is starting this" picker),
/// and — with [role]/[phoneNumber]/[email] — a full roster entry managed
/// on its own Employee screen. Still not a login/auth record: this app has
/// no auth system, so [id] (the Firestore doc id) is only ever used as a
/// QR-coded identifier printed on a staff badge, never as a credential.
class StaffMember {
  const StaffMember({
    required this.id,
    required this.name,
    this.role = '',
    this.phoneNumber,
    this.email,
    this.createdAt,
  });

  final String id;
  final String name;
  final String role;
  final String? phoneNumber;
  final String? email;
  final DateTime? createdAt;

  factory StaffMember.fromMap(String id, Map<String, dynamic> data) {
    final createdAtMillis = data['createdAtMillis'] as int?;
    return StaffMember(
      id: id,
      name: data['name'] as String,
      role: data['role'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String?,
      email: data['email'] as String?,
      createdAt: createdAtMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(createdAtMillis),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'role': role,
    if (phoneNumber != null) 'phoneNumber': phoneNumber,
    if (email != null) 'email': email,
    if (createdAt != null) 'createdAtMillis': createdAt!.millisecondsSinceEpoch,
  };

  StaffMember copyWith({String? name, String? role, String? phoneNumber, String? email}) {
    return StaffMember(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      createdAt: createdAt,
    );
  }
}
