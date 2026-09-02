import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/staff_member.dart';

/// Firestore-backed storage for the staff roster — shared across every
/// feature that needs to record "who did this" (starting with the Sushi
/// Rice SOP). No seeded defaults: unlike Log Sheet locations, placeholder
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

  Future<StaffMember> add(String name) async {
    final trimmed = name.trim();
    final doc = await _collection.add({'name': trimmed});
    return StaffMember(id: doc.id, name: trimmed);
  }

  Future<void> remove(String id) => _collection.doc(id).delete();
}
