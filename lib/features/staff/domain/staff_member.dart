/// A named staff member selectable when recording who handled a step of a
/// procedure (e.g. the Sushi Rice SOP's "who is starting this" picker) —
/// deliberately just a name, not a full employee/auth record, since this
/// app has no login system.
class StaffMember {
  const StaffMember({required this.id, required this.name});

  final String id;
  final String name;

  factory StaffMember.fromMap(String id, Map<String, dynamic> data) {
    return StaffMember(id: id, name: data['name'] as String);
  }

  Map<String, dynamic> toMap() => {'name': name};
}
