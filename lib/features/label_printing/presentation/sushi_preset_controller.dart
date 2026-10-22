import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/sushi_label_preset_repository.dart';
import '../domain/sushi_template_label_data.dart';

const _uuid = Uuid();

/// Saved Sushi Template Label presets, backed by
/// [SushiLabelPresetRepository] — mirrors [FoodCatalogController]'s shape
/// (a plain synchronous list the controller keeps mirrored from a
/// Firestore stream) so the rest of the UI never deals with an
/// `AsyncValue`.
class SushiPresetController extends StateNotifier<List<SushiLabelPreset>> {
  SushiPresetController(this._repository, {void Function()? onFirstLoad})
      : _onFirstLoad = onFirstLoad,
        super(const []) {
    _subscription = _repository.watchAll().listen(
      (items) {
        state = items;
        _onFirstLoad?.call();
      },
      onError: (Object _) => _onFirstLoad?.call(),
    );
  }

  final SushiLabelPresetRepository _repository;
  final void Function()? _onFirstLoad;
  StreamSubscription<List<SushiLabelPreset>>? _subscription;

  /// Whole days from today's date to [at] — the inverse of
  /// [sushiLabelDataFromPreset]'s `today.add(Duration(days: ...))`, so
  /// saving a preset captures the number the user actually typed rather
  /// than a date that would go stale.
  static int _daysUntil(DateTime at) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return at.difference(today).inDays.clamp(0, 1 << 30);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// Saves [data] as a new preset named [name]. Returns the created preset
  /// so the caller can bind to it immediately.
  Future<SushiLabelPreset> createFromLabelData(
    String name,
    SushiTemplateLabelData data,
  ) async {
    final preset = _presetFrom(name, data);
    await _repository.setPreset(preset);
    return preset;
  }

  /// Overwrites the preset bound to [id] with [data]'s current field
  /// values — "Save" on an already-loaded preset. Never duplicates:
  /// writing to the same id always replaces that one document.
  Future<void> updateFromLabelData(
    String id,
    String name,
    SushiTemplateLabelData data,
  ) async {
    final existing = state.where((p) => p.id == id).firstOrNull;
    await _repository.setPreset(
      SushiLabelPreset(
        id: id,
        name: name,
        productTitle: data.productTitle,
        fullyCookedText: data.fullyCookedText,
        netWeightText: data.netWeightText,
        bestIfUseByLabel: data.bestIfUseByLabel,
        bestIfUseByDays: _daysUntil(data.bestIfUseByAt),
        processedOnLabel: data.processedOnLabel,
        price: data.price,
        rollDescription: data.rollDescription,
        topDescription: data.topDescription,
        barcodeType: data.barcodeType,
        barcodeValue: data.barcodeValue,
        createdAt: existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Creates an independent copy of [source] named [name] — edits to the
  /// copy never affect the original.
  Future<SushiLabelPreset> copyPreset(SushiLabelPreset source, String name) async {
    final copy = _repository.newPresetFrom(source, name: name);
    await _repository.setPreset(copy);
    return copy;
  }

  Future<void> renamePreset(SushiLabelPreset preset, String newName) =>
      _repository.setPreset(preset.copyWith(name: newName, updatedAt: DateTime.now()));

  Future<void> deletePreset(String id) => _repository.deletePreset(id);

  SushiLabelPreset _presetFrom(String name, SushiTemplateLabelData data) {
    final now = DateTime.now();
    return SushiLabelPreset(
      id: _uuid.v4(),
      name: name,
      productTitle: data.productTitle,
      fullyCookedText: data.fullyCookedText,
      netWeightText: data.netWeightText,
      bestIfUseByLabel: data.bestIfUseByLabel,
      bestIfUseByDays: _daysUntil(data.bestIfUseByAt),
      processedOnLabel: data.processedOnLabel,
      price: data.price,
      rollDescription: data.rollDescription,
      topDescription: data.topDescription,
      barcodeType: data.barcodeType,
      barcodeValue: data.barcodeValue,
      createdAt: now,
      updatedAt: now,
    );
  }
}

/// Converts a saved [SushiLabelPreset] back into [SushiTemplateLabelData]
/// for a fresh print job. Best If Use By is [SushiLabelPreset.bestIfUseByDays]
/// applied to *today's* date — the saved day count carries over, but it's
/// always computed from today, never a stale saved absolute date.
/// Processed On always resets to "now".
SushiTemplateLabelData sushiLabelDataFromPreset(SushiLabelPreset preset) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return SushiTemplateLabelData(
    productTitle: preset.productTitle,
    fullyCookedText: preset.fullyCookedText,
    netWeightText: preset.netWeightText,
    bestIfUseByLabel: preset.bestIfUseByLabel,
    bestIfUseByAt: today.add(Duration(days: preset.bestIfUseByDays)),
    processedOnLabel: preset.processedOnLabel,
    processedOnAt: now,
    price: preset.price,
    rollDescription: preset.rollDescription,
    topDescription: preset.topDescription,
    barcodeType: preset.barcodeType,
    barcodeValue: preset.barcodeValue,
  );
}

final sushiLabelPresetRepositoryProvider = Provider<SushiLabelPresetRepository>(
  (ref) => SushiLabelPresetRepository(),
);

final sushiPresetLoadedProvider = StateProvider<bool>((ref) => false);

final sushiPresetControllerProvider =
    StateNotifierProvider<SushiPresetController, List<SushiLabelPreset>>(
  (ref) => SushiPresetController(
    ref.watch(sushiLabelPresetRepositoryProvider),
    onFirstLoad: () => ref.read(sushiPresetLoadedProvider.notifier).state = true,
  ),
);

/// Current search box text for the Select Sushi Template screen, trimmed
/// and lower-cased for matching.
final sushiPresetSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredSushiPresetsProvider = Provider<List<SushiLabelPreset>>((ref) {
  final query = ref.watch(sushiPresetSearchQueryProvider).trim().toLowerCase();
  final all = ref.watch(sushiPresetControllerProvider);
  if (query.isEmpty) return all;
  return all.where((p) => p.name.toLowerCase().contains(query)).toList();
});
