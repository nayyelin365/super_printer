import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/staff_member.dart';

/// Firestore-backed storage for the staff roster — shared across every
/// feature that needs to record "who did this" (starting with the Sushi
/// Rice SOP), and now also the Employee CRUD screen's own roster
/// management. No seeded defaults: unlike Log Sheet locations, placeholder
/// staff names would be fake data, so the list starts empty until real
/// names are added.
class StaffRepository {
  StaffRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('employees');

  Stream<List<StaffMember>> watchAll() {
    return _collection
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map((doc) => StaffMember.fromMap(doc.id, doc.data())).toList());
  }

  /// Full create from the Employee screen's "Add Employee" form — the only
  /// way a staff member enters the roster. [StaffNamePicker] only ever
  /// identifies someone already in it (by scanning their QR badge), it
  /// never creates one.
  Future<StaffMember> create({
    required String name,
    required String role,
    String? phoneNumber,
    String? email,
  }) async {
    final member = StaffMember(
      id: '',
      name: name.trim(),
      role: role,
      phoneNumber: phoneNumber?.trim().isEmpty ?? true ? null : phoneNumber!.trim(),
      email: email?.trim().isEmpty ?? true ? null : email!.trim(),
      createdAt: DateTime.now(),
    );
    final doc = await _collection.add(member.toMap());
    return StaffMember(
      id: doc.id,
      name: member.name,
      role: member.role,
      phoneNumber: member.phoneNumber,
      email: member.email,
      createdAt: member.createdAt,
    );
  }

  Future<void> update(StaffMember member) => _collection.doc(member.id).update(member.toMap());

  Future<void> remove(String id) => _collection.doc(id).delete();
}
