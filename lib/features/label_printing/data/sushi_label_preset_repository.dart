import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../domain/sushi_barcode.dart';

const _uuid = Uuid();

/// A named, reusable set of Sushi Template Label field values. Deliberately
/// excludes the two live dates (Best If Use By / Processed On) — those
/// always reset to "now" (+ offset) when a preset is loaded for a new
/// print job, never a stale saved timestamp; see
/// `SushiPresetController.toLabelData`.
class SushiLabelPreset {
  const SushiLabelPreset({
    required this.id,
    required this.name,
    required this.productTitle,
    required this.fullyCookedText,
    required this.netWeightText,
    required this.bestIfUseByLabel,
    required this.processedOnLabel,
    required this.price,
    required this.rollDescription,
    required this.topDescription,
    required this.barcodeType,
    required this.barcodeValue,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String productTitle;
  final String fullyCookedText;
  final String netWeightText;
  final String bestIfUseByLabel;
  final String processedOnLabel;
  final double price;
  final String rollDescription;
  final String topDescription;
  final SushiBarcodeType barcodeType;
  final String barcodeValue;
  final DateTime createdAt;
  final DateTime updatedAt;

  SushiLabelPreset copyWith({
    String? name,
    String? productTitle,
    String? fullyCookedText,
    String? netWeightText,
    String? bestIfUseByLabel,
    String? processedOnLabel,
    double? price,
    String? rollDescription,
    String? topDescription,
    SushiBarcodeType? barcodeType,
    String? barcodeValue,
    DateTime? updatedAt,
  }) {
    return SushiLabelPreset(
      id: id,
      name: name ?? this.name,
      productTitle: productTitle ?? this.productTitle,
      fullyCookedText: fullyCookedText ?? this.fullyCookedText,
      netWeightText: netWeightText ?? this.netWeightText,
      bestIfUseByLabel: bestIfUseByLabel ?? this.bestIfUseByLabel,
      processedOnLabel: processedOnLabel ?? this.processedOnLabel,
      price: price ?? this.price,
      rollDescription: rollDescription ?? this.rollDescription,
      topDescription: topDescription ?? this.topDescription,
      barcodeType: barcodeType ?? this.barcodeType,
      barcodeValue: barcodeValue ?? this.barcodeValue,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'productTitle': productTitle,
        'fullyCookedText': fullyCookedText,
        'netWeightText': netWeightText,
        'bestIfUseByLabel': bestIfUseByLabel,
        'processedOnLabel': processedOnLabel,
        'price': price,
        'rollDescription': rollDescription,
        'topDescription': topDescription,
        'barcodeType': barcodeType.name,
        'barcodeValue': barcodeValue,
        'createdAtMillis': createdAt.millisecondsSinceEpoch,
        'updatedAtMillis': updatedAt.millisecondsSinceEpoch,
      };

  factory SushiLabelPreset.fromJson(String id, Map<String, dynamic> json) {
    return SushiLabelPreset(
      id: id,
      name: json['name'] as String? ?? 'Untitled',
      productTitle: json['productTitle'] as String? ?? '',
      fullyCookedText: json['fullyCookedText'] as String? ?? '',
      netWeightText: json['netWeightText'] as String? ?? '',
      bestIfUseByLabel: json['bestIfUseByLabel'] as String? ?? 'Sell Through',
      processedOnLabel: json['processedOnLabel'] as String? ?? 'Processed On',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      rollDescription: json['rollDescription'] as String? ?? '',
      topDescription: json['topDescription'] as String? ?? '',
      barcodeType: SushiBarcodeType.values.asNameMap()[json['barcodeType']] ??
          SushiBarcodeType.ean13,
      barcodeValue: json['barcodeValue'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAtMillis'] as int? ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAtMillis'] as int? ?? 0),
    );
  }
}

/// Firestore-backed storage for saved Sushi Template Label presets —
/// shared across every device, same as the rest of the app's kitchen data.
class SushiLabelPresetRepository {
  SushiLabelPresetRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('sushi_label_presets');

  /// Live preset list, sorted by name client-side (filtering by one field
  /// only — no composite index to deploy, per this project's Firestore
  /// convention).
  Stream<List<SushiLabelPreset>> watchAll() {
    return _collection.snapshots().map((snapshot) {
      final items = snapshot.docs
          .map((doc) => SushiLabelPreset.fromJson(doc.id, doc.data()))
          .toList();
      items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return items;
    });
  }

  /// Creates or fully overwrites (by id) — the single write path for both
  /// "Save" on an already-bound preset and renaming, so neither can ever
  /// produce a duplicate document.
  Future<void> setPreset(SushiLabelPreset preset) =>
      _collection.doc(preset.id).set(preset.toJson());

  Future<void> deletePreset(String id) => _collection.doc(id).delete();

  /// Builds a brand-new preset (fresh id, `name`, copying every other
  /// field from [source]) — used by both "Create New" (from the current
  /// in-progress label) and "Copy Template" (from an existing preset).
  SushiLabelPreset newPresetFrom(SushiLabelPreset source, {required String name}) {
    final now = DateTime.now();
    return SushiLabelPreset(
      id: _uuid.v4(),
      name: name,
      productTitle: source.productTitle,
      fullyCookedText: source.fullyCookedText,
      netWeightText: source.netWeightText,
      bestIfUseByLabel: source.bestIfUseByLabel,
      processedOnLabel: source.processedOnLabel,
      price: source.price,
      rollDescription: source.rollDescription,
      topDescription: source.topDescription,
      barcodeType: source.barcodeType,
      barcodeValue: source.barcodeValue,
      createdAt: now,
      updatedAt: now,
    );
  }
}
