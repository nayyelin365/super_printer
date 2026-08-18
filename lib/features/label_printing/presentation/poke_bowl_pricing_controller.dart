import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/poke_bowl_pricing_storage.dart';
import '../domain/poke_bowl_pricing.dart';

class PokeBowlPricingState {
  const PokeBowlPricingState({
    this.basePrices = defaultBasePriceOptions,
    this.extras = defaultExtraPriceOptions,
  });

  final List<BasePriceOption> basePrices;
  final List<ExtraPriceOption> extras;

  PokeBowlPricingState copyWith({
    List<BasePriceOption>? basePrices,
    List<ExtraPriceOption>? extras,
  }) {
    return PokeBowlPricingState(
      basePrices: basePrices ?? this.basePrices,
      extras: extras ?? this.extras,
    );
  }
}

/// Base/extra pricing for the Poke Bowl / Burrito template, seeded from the
/// code-defined defaults and overridden by whatever the seller has edited
/// (see [updateBasePrice]/[updateExtraPrice]) — every mutation is persisted
/// immediately via [PokeBowlPricingStorage].
class PokeBowlPricingController extends StateNotifier<PokeBowlPricingState> {
  PokeBowlPricingController(this._storage) : super(const PokeBowlPricingState()) {
    _restore();
  }

  final PokeBowlPricingStorage _storage;

  Future<void> _restore() async {
    final saved = await _storage.load();
    if (saved == null) return;

    final baseOverrides = {
      for (final entry in (saved['basePrices'] as List<dynamic>? ?? []))
        (entry as Map<String, dynamic>)['id'] as String: entry,
    };
    final extraOverrides = {
      for (final entry in (saved['extras'] as List<dynamic>? ?? []))
        (entry as Map<String, dynamic>)['id'] as String: entry,
    };

    state = PokeBowlPricingState(
      basePrices: [
        for (final option in defaultBasePriceOptions)
          _withBaseOverride(option, baseOverrides[option.id]),
      ],
      extras: [
        for (final option in defaultExtraPriceOptions)
          _withExtraOverride(option, extraOverrides[option.id]),
      ],
    );
  }

  BasePriceOption _withBaseOverride(BasePriceOption option, Map<String, dynamic>? override) {
    if (override == null) return option;
    return option.copyWith(
      label: override['label'] as String,
      amount: (override['amount'] as num).toDouble(),
    );
  }

  ExtraPriceOption _withExtraOverride(ExtraPriceOption option, Map<String, dynamic>? override) {
    if (override == null) return option;
    return option.copyWith(
      label: override['label'] as String,
      amount: (override['amount'] as num).toDouble(),
    );
  }

  Future<void> updateBasePrice(String id, {required String label, required double amount}) async {
    final basePrices = [
      for (final option in state.basePrices)
        option.id == id ? option.copyWith(label: label, amount: amount) : option,
    ];
    state = state.copyWith(basePrices: basePrices);
    await _persist();
  }

  Future<void> updateExtraPrice(String id, {required String label, required double amount}) async {
    final extras = [
      for (final option in state.extras)
        option.id == id ? option.copyWith(label: label, amount: amount) : option,
    ];
    state = state.copyWith(extras: extras);
    await _persist();
  }

  Future<void> _persist() {
    return _storage.save(
      basePrices: [
        for (final option in state.basePrices)
          {'id': option.id, 'label': option.label, 'amount': option.amount},
      ],
      extras: [
        for (final option in state.extras)
          {'id': option.id, 'label': option.label, 'amount': option.amount},
      ],
    );
  }
}

final pokeBowlPricingStorageProvider = Provider<PokeBowlPricingStorage>(
  (ref) => PokeBowlPricingStorage(),
);

final pokeBowlPricingProvider =
    StateNotifierProvider<PokeBowlPricingController, PokeBowlPricingState>(
  (ref) => PokeBowlPricingController(ref.watch(pokeBowlPricingStorageProvider)),
);
