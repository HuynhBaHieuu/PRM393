import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/extensions/string_extensions.dart';
import 'package:all_fits/core/utils/id_generator.dart';
import 'package:all_fits/core/utils/load_status.dart';
import 'package:all_fits/data/models/shopping_item.dart';
import 'package:all_fits/data/repositories/shopping_repository.dart';
import 'package:all_fits/features/shopping/controllers/shopping_draft.dart';

/// Owns the shopping list and every mutation of it.
class ShoppingController extends ChangeNotifier {
  ShoppingController({
    required this._repository,
    IdGenerator idGenerator = const UuidIdGenerator(),
    this._clock = systemClock,
  }) : _ids = idGenerator;

  final ShoppingRepository _repository;
  final IdGenerator _ids;
  final Clock _clock;

  LoadStatus _status = LoadStatus.idle;
  Object? _error;
  Map<String, ShoppingItem> _byId = const {};
  List<ShoppingItem> _toBuy = const [];
  List<ShoppingItem> _purchased = const [];

  LoadStatus get status => _status;
  Object? get error => _error;

  /// Items still to buy, most wanted first, then newest.
  List<ShoppingItem> get toBuy => _toBuy;

  /// Bought items, most recently bought first.
  List<ShoppingItem> get purchased => _purchased;

  /// Expected cost of everything still on the list.
  double get toBuyTotal => _sumPrices(_toBuy);

  /// What was paid for bought items.
  double get spentTotal => _sumPrices(_purchased);

  ShoppingItem? itemById(String id) => _byId[id];

  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _setItems(await _repository.fetchAll());
      _status = LoadStatus.ready;
    } catch (error) {
      _status = LoadStatus.failure;
      _error = error;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<ShoppingItem> addItem(ShoppingDraft draft) async {
    draft.ensureValid();
    final now = _clock();
    final item = ShoppingItem(
      id: _ids.next(),
      name: draft.name.trim(),
      category: draft.category!,
      color: draft.color,
      brand: draft.brand.trimmedOrNull,
      price: draft.price,
      link: draft.link.trimmedOrNull,
      notes: draft.notes.trimmedOrNull,
      priority: draft.priority,
      createdAt: now,
      updatedAt: now,
    );
    await _commit([item]);
    return item;
  }

  Future<ShoppingItem> updateItem(String id, ShoppingDraft draft) async {
    final existing = _require(id);
    draft.ensureValid();
    final updated = existing.copyWith(
      name: draft.name.trim(),
      category: draft.category,
      color: draft.color,
      brand: draft.brand.trimmedOrNull,
      price: draft.price,
      link: draft.link.trimmedOrNull,
      notes: draft.notes.trimmedOrNull,
      priority: draft.priority,
      updatedAt: _clock(),
    );
    await _commit([updated]);
    return updated;
  }

  /// Moves an item between "to buy" and "bought".
  Future<void> setPurchased(String id, {required bool purchased}) async {
    final item = _require(id);
    if (item.isPurchased == purchased) return;
    final now = _clock();
    await _commit([
      item.copyWith(purchasedAt: purchased ? now : null, updatedAt: now),
    ]);
  }

  /// Records that [id] was added to the wardrobe as [wardrobeItemId],
  /// marking it bought if it wasn't already.
  Future<void> linkToWardrobe(String id, String wardrobeItemId) async {
    final item = _require(id);
    final now = _clock();
    await _commit([
      item.copyWith(
        wardrobeItemId: wardrobeItemId,
        purchasedAt: item.purchasedAt ?? now,
        updatedAt: now,
      ),
    ]);
  }

  Future<void> deleteItem(String id) async {
    if (!_byId.containsKey(id)) return;
    await _repository.deleteAll([id]);
    _setItems(_byId.values.where((item) => item.id != id));
    notifyListeners();
  }

  /// Removes every bought item from the list.
  Future<void> clearPurchased() async {
    final ids = _purchased.map((item) => item.id).toSet();
    if (ids.isEmpty) return;
    await _repository.deleteAll(ids);
    _setItems(_toBuy);
    notifyListeners();
  }

  Future<void> clearAll() async {
    await _repository.clear();
    _setItems(const []);
    notifyListeners();
  }

  ShoppingItem _require(String id) {
    final item = _byId[id];
    if (item == null) {
      developer.log('Missing shopping item $id', name: 'shopping');
      throw const NotFoundException(
        'This item is no longer on your shopping list.',
      );
    }
    return item;
  }

  Future<void> _commit(List<ShoppingItem> changed) async {
    await _repository.saveAll(changed);
    final next = Map.of(_byId);
    for (final item in changed) {
      next[item.id] = item;
    }
    _setItems(next.values);
    notifyListeners();
  }

  void _setItems(Iterable<ShoppingItem> items) {
    final all = items.toList();
    _byId = {for (final item in all) item.id: item};
    _toBuy = List.unmodifiable(
      all.where((item) => !item.isPurchased).toList()..sort((a, b) {
        final byPriority = b.priority.index.compareTo(a.priority.index);
        return byPriority != 0
            ? byPriority
            : b.createdAt.compareTo(a.createdAt);
      }),
    );
    _purchased = List.unmodifiable(
      all.where((item) => item.isPurchased).toList()
        ..sort((a, b) => b.purchasedAt!.compareTo(a.purchasedAt!)),
    );
  }

  static double _sumPrices(Iterable<ShoppingItem> items) =>
      items.fold(0, (sum, item) => sum + (item.price ?? 0));
}
