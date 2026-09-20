import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore-backed custom names for the food catalog's color groups (e.g.
/// renaming the green group to "Proteins") — one document per color, keyed
/// by the color's ARGB int, so it lines up with `FoodModel.color`. A color
/// with no document just shows its default "Green group"-style title.
class FoodGroupNameRepository {
  FoodGroupNameRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('food_group_names');

  /// Live map of color ARGB value -> custom group name.
  Stream<Map<int, String>> watchAll() {
    return _collection.snapshots().map((snapshot) {
      return {
        for (final doc in snapshot.docs)
          if (int.tryParse(doc.id) != null && (doc.data()['name'] as String?) != null)
            int.parse(doc.id): doc.data()['name'] as String,
      };
    });
  }

  /// Saves [name] for [colorValue]; a blank name removes the custom name so
  /// the group falls back to its default title.
  Future<void> setName(int colorValue, String name) {
    final trimmed = name.trim();
    final doc = _collection.doc('$colorValue');
    return trimmed.isEmpty ? doc.delete() : doc.set({'name': trimmed});
  }
}
