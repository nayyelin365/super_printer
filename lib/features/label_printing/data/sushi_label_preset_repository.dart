import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../domain/sushi_barcode.dart';

const _uuid = Uuid();

/// A named, reusable set of Sushi Template Label field values. Deliberately
/// excludes the two live dates (Best If Use By / Processed On) — those
/// always reset relative to "now" when a preset is loaded for a new print
/// job, never a stale saved absolute timestamp. [bestIfUseByDays] is the
/// one exception: it's the number the user actually typed (days from
/// today), not a date, so it's meaningful to save and reapply to whatever
/// "today" is at load time; see `sushiLabelDataFromPreset`.
class SushiLabelPreset {
  const SushiLabelPreset({
    required this.id,
    required this.name,
    required this.productTitle,
    required this.fullyCookedText,
    required this.netWeightText,
    required this.bestIfUseByLabel,
    required this.bestIfUseByDays,
    required this.processedOnLabel,
    required this.price,
    required this.rollDescription,
    required this.topDescription,
    required this.ingredientsText,
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
  final int bestIfUseByDays;
  final String processedOnLabel;
  final double price;
  final String rollDescription;
  final String topDescription;
  final String ingredientsText;
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
    int? bestIfUseByDays,
    String? processedOnLabel,
    double? price,
    String? rollDescription,
    String? topDescription,
    String? ingredientsText,
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
      bestIfUseByDays: bestIfUseByDays ?? this.bestIfUseByDays,
      processedOnLabel: processedOnLabel ?? this.processedOnLabel,
      price: price ?? this.price,
      rollDescription: rollDescription ?? this.rollDescription,
      topDescription: topDescription ?? this.topDescription,
      ingredientsText: ingredientsText ?? this.ingredientsText,
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
        'bestIfUseByDays': bestIfUseByDays,
        'processedOnLabel': processedOnLabel,
        'price': price,
        'rollDescription': rollDescription,
        'topDescription': topDescription,
        'ingredientsText': ingredientsText,
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
      bestIfUseByDays: json['bestIfUseByDays'] as int? ?? 1,
      processedOnLabel: json['processedOnLabel'] as String? ?? 'Processed On',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      rollDescription: json['rollDescription'] as String? ?? '',
      topDescription: json['topDescription'] as String? ?? '',
      ingredientsText: json['ingredientsText'] as String? ?? '',
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
      bestIfUseByDays: source.bestIfUseByDays,
      processedOnLabel: source.processedOnLabel,
      price: source.price,
      rollDescription: source.rollDescription,
      topDescription: source.topDescription,
      ingredientsText: source.ingredientsText,
      barcodeType: source.barcodeType,
      barcodeValue: source.barcodeValue,
      createdAt: now,
      updatedAt: now,
    );
  }
}
