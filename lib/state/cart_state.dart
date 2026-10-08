import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';
import '../services/catalog_api.dart';

class CartLine {
  const CartLine({
    required this.id,
    required this.quantity,
    this.addedPrice,
    this.addedStock,
    this.product,
    this.reason,
  });

  final String id;
  final int quantity;
  final double? addedPrice;
  final int? addedStock;
  final Product? product;
  final String? reason;

  bool get priceChanged =>
      product != null &&
      addedPrice != null &&
      priceToCents(product!.price) != priceToCents(addedPrice!);
  bool get stockChanged =>
      product != null && addedStock != null && product!.stock != addedStock;
  int get totalCents => product == null || !product!.isActive
      ? 0
      : priceToCents(product!.price) * quantity;

  Map<String, dynamic> _snapshot() => {
    'id': id,
    'quantity': quantity,
    'addedPrice': addedPrice,
    'addedStock': addedStock,
  };
}

class CartState extends ChangeNotifier {
  CartState({required this._api, required this._preferences});

  static const storageKey = 'tcg404.cart.v1';
  final CatalogApi _api;
  final SharedPreferences _preferences;
  List<CartLine> _lines = [];
  List<String> _completedOrders = [];
  Future<void> _pending = Future.value();
  bool _ready = false;
  bool _restoreFailed = false;
  bool _busy = false;
  bool _disposed = false;
  String? _notice;
  String? _error;

  bool get ready => _ready;
  bool get restoreFailed => _restoreFailed;
  bool get busy => _busy;
  String? get notice => _notice;
  String? get error => _error;
  List<CartLine> get lines => List.unmodifiable(_lines);
  int get count => _lines.fold(0, (sum, line) => sum + line.quantity);
  int get subtotalCents => _lines.fold(0, (sum, line) => sum + line.totalCents);
  bool get valid =>
      _ready &&
      !_busy &&
      _error == null &&
      _lines.isNotEmpty &&
      _lines.every(
        (line) =>
            line.product != null &&
            line.product!.isActive &&
            line.quantity <= line.product!.stock &&
            line.reason == null,
      );

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<T> _run<T>(Future<T> Function() operation) {
    final result = _pending.then((_) async {
      _busy = true;
      _notify();
      try {
        return await operation();
      } finally {
        _busy = false;
        _notify();
      }
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> restore() => _run(() async {
    try {
      final raw = _preferences.getString(storageKey);
      if (raw != null) {
        if (raw.length > 65536) throw const FormatException();
        final saved = jsonDecode(raw);
        if (saved is! Map<String, dynamic> ||
            saved['version'] != 1 ||
            saved['lines'] is! List ||
            (saved['lines'] as List).length > 50) {
          throw const FormatException();
        }
        final restored = <CartLine>[];
        final ids = <String>{};
        for (final value in saved['lines'] as List) {
          if (value is! Map<String, dynamic>) throw const FormatException();
          final id = value['id'];
          final quantity = value['quantity'];
          final price = value['addedPrice'];
          final stock = value['addedStock'];
          if (id is! String ||
              id.isEmpty ||
              id.length > 200 ||
              !ids.add(id) ||
              quantity is! int ||
              quantity < 1 ||
              quantity > 999 ||
              (price != null && price is! num) ||
              (stock != null &&
                  (stock is! int || stock < 0 || stock > 9007199254740991))) {
            throw const FormatException();
          }
          final addedPrice = (price as num?)?.toDouble();
          if (addedPrice != null) priceToCents(addedPrice);
          restored.add(
            CartLine(
              id: id,
              quantity: quantity,
              addedPrice: addedPrice,
              addedStock: stock as int?,
            ),
          );
        }
        _lines = restored;
        final completed = saved['completedOrders'] ?? <dynamic>[];
        if (completed is! List ||
            completed.length > 50 ||
            completed.any(
              (id) => id is! String || id.isEmpty || id.length > 200,
            )) {
          throw const FormatException();
        }
        _completedOrders = completed.cast<String>();
      }
      _error = null;
      _restoreFailed = false;
    } catch (_) {
      _restoreFailed = true;
      _error =
          'Your saved cart could not be restored. Its saved data was kept.';
      _ready = true;
      return;
    }
    _ready = true;
    await _refresh();
  });

  Future<void> refresh() => _restoreFailed ? restore() : _run(_refresh);

  Future<void> resetSavedCart() => _run(() async {
    _restoreFailed = false;
    if (!await _save([])) _restoreFailed = true;
  });

  static String? _availability(Product product, int quantity) {
    if (!product.isActive) return 'This card is no longer available.';
    if (product.stock == 0) return 'Out of stock.';
    if (quantity > product.stock) {
      return 'Only ${product.stock} available. Reduce the quantity.';
    }
    return null;
  }

  Future<void> _refresh() async {
    var networkFailure = false;
    _lines = await Future.wait(
      _lines.map((line) async {
        try {
          final product = await _api.product(line.id);
          return CartLine(
            id: line.id,
            quantity: line.quantity,
            addedPrice: line.addedPrice,
            addedStock: line.addedStock,
            product: product,
            reason: _availability(product, line.quantity),
          );
        } on CatalogException catch (failure) {
          if (failure.statusCode == 404) {
            return CartLine(
              id: line.id,
              quantity: line.quantity,
              addedPrice: line.addedPrice,
              addedStock: line.addedStock,
              reason: 'This card is no longer available.',
            );
          }
          networkFailure = true;
          return CartLine(
            id: line.id,
            quantity: line.quantity,
            addedPrice: line.addedPrice,
            addedStock: line.addedStock,
            product: line.product,
            reason: 'Could not verify current price and stock.',
          );
        }
      }),
    );
    _error = networkFailure
        ? 'Could not refresh your cart. Check your connection and try again.'
        : null;
    _updateNotice();
  }

  void _updateNotice() {
    _notice =
        _lines.any(
          (line) =>
              line.priceChanged || line.stockChanged || line.reason != null,
        )
        ? 'Prices or availability changed. Review your cart.'
        : null;
  }

  Future<bool> _save(
    List<CartLine> proposed, {
    List<String>? completedOrders,
  }) async {
    if (_restoreFailed) {
      _error = 'Restore or reset your saved cart before making changes.';
      return false;
    }
    try {
      final saved = await _preferences.setString(
        storageKey,
        jsonEncode({
          'version': 1,
          'lines': proposed.map((line) => line._snapshot()).toList(),
          'completedOrders': completedOrders ?? _completedOrders,
        }),
      );
      if (!saved) throw const FormatException();
      _lines = proposed;
      if (completedOrders != null) _completedOrders = completedOrders;
      _error = null;
      _updateNotice();
      return true;
    } catch (_) {
      _error = 'Your cart could not be saved. Try again.';
      return false;
    }
  }

  Future<String?> add(Product product, int quantity) => _run(() async {
    if (!_ready) return 'Your cart is still loading.';
    if (quantity < 1 || quantity > 999) {
      return 'Choose a quantity from 1 to 999.';
    }
    final existing = _lines.where((line) => line.id == product.id).firstOrNull;
    if (existing == null && _lines.length >= 50) {
      return 'Your cart can hold up to 50 different cards.';
    }
    final nextQuantity = (existing?.quantity ?? 0) + quantity;
    if (nextQuantity > 999) return 'Choose a quantity from 1 to 999.';
    return _change(product.id, nextQuantity);
  });

  Future<String?> setQuantity(String id, int quantity) => _run(() async {
    if (!_ready) return 'Your cart is still loading.';
    if (!_lines.any((line) => line.id == id)) {
      return 'This card is not in your cart.';
    }
    if (quantity < 1 || quantity > 999) {
      return 'Choose a quantity from 1 to 999.';
    }
    return _change(id, quantity);
  });

  Future<String?> _change(String id, int quantity) async {
    try {
      final current = await _api.product(id);
      final reason = _availability(current, quantity);
      if (reason != null) {
        _lines = _lines
            .map(
              (line) => line.id == id
                  ? CartLine(
                      id: id,
                      quantity: line.quantity,
                      addedPrice: line.addedPrice,
                      addedStock: line.addedStock,
                      product: current,
                      reason: _availability(current, line.quantity),
                    )
                  : line,
            )
            .toList();
        _updateNotice();
        return reason;
      }
      final changed = CartLine(
        id: id,
        quantity: quantity,
        product: current,
        addedPrice: current.price,
        addedStock: current.stock,
      );
      final proposed = [..._lines];
      final index = proposed.indexWhere((line) => line.id == id);
      if (index < 0) {
        proposed.add(changed);
      } else {
        proposed[index] = changed;
      }
      return await _save(proposed) ? null : _error;
    } on CatalogException catch (failure) {
      _error = failure.message;
      _lines = _lines
          .map(
            (line) => line.id == id
                ? CartLine(
                    id: id,
                    quantity: line.quantity,
                    addedPrice: line.addedPrice,
                    addedStock: line.addedStock,
                    product: failure.statusCode == 404 ? null : line.product,
                    reason: failure.statusCode == 404
                        ? 'This card is no longer available.'
                        : 'Could not verify current price and stock.',
                  )
                : line,
          )
          .toList();
      _updateNotice();
      return _error;
    }
  }

  Future<void> remove(String id) => _run(() async {
    if (_lines.any((line) => line.id == id)) {
      await _save(_lines.where((line) => line.id != id).toList());
    }
  });

  Future<bool> completeOrder(String orderId, Map<String, int> purchased) =>
      _run(() async {
        if (_completedOrders.contains(orderId)) return true;
        final remaining = <CartLine>[];
        for (final line in _lines) {
          final quantity = line.quantity - (purchased[line.id] ?? 0);
          if (quantity > 0) {
            remaining.add(
              CartLine(
                id: line.id,
                quantity: quantity,
                product: line.product,
                addedPrice: line.addedPrice,
                addedStock: line.addedStock,
                reason: line.reason,
              ),
            );
          }
        }
        final completed = [..._completedOrders, orderId];
        return _save(
          remaining,
          completedOrders: completed.length > 50
              ? completed.sublist(completed.length - 50)
              : completed,
        );
      });

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
