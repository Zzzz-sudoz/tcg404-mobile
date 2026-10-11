import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../services/commerce_api.dart';
import 'auth_state.dart';

class FavoriteEntry {
  const FavoriteEntry(this.productId, this.product, this.available);
  final String productId;
  final Product? product;
  final bool available;
}

class FavoritesState extends ChangeNotifier {
  FavoritesState({required this.api, required this.auth}) {
    auth.addListener(_accountChanged);
    _accountChanged();
  }
  final CommerceApi api;
  final AuthState auth;
  List<FavoriteEntry> entries = const [];
  final Set<String> pending = {};
  String? error, _owner;
  bool loading = false, _disposed = false;
  int _generation = 0;
  bool contains(String id) => entries.any((entry) => entry.productId == id);
  void _accountChanged() {
    final owner = auth.user?.role == 'customer' ? auth.user?.id : null;
    if (owner == _owner) return;
    _owner = owner;
    _generation++;
    entries = const [];
    error = null;
    pending.clear();
    loading = false;
    notifyListeners();
    if (owner != null) load();
  }

  Future<void> load() async {
    if (_owner == null || _disposed) return;
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final rows = <FavoriteEntry>[];
      var page = 1, pages = 1;
      do {
        final result = await api.request(
          'GET',
          'favorites',
          query: {'page': '$page', 'limit': '100'},
        );
        if (_disposed || generation != _generation) return;
        final data = result['data'], meta = result['meta'];
        if (data is! List ||
            meta is! Map ||
            meta['totalPages'] is! int ||
            meta['totalPages'] < 1) {
          throw const FormatException('Invalid favorites response.');
        }
        for (final row in data) {
          if (row is! Map ||
              row['productId'] is! String ||
              row['available'] is! bool ||
              (row['product'] != null &&
                  row['product'] is! Map<String, dynamic>)) {
            throw const FormatException('Invalid favorite.');
          }
          rows.add(
            FavoriteEntry(
              row['productId'] as String,
              row['product'] == null
                  ? null
                  : Product.fromJson(row['product'] as Map<String, dynamic>),
              row['available'] as bool,
            ),
          );
        }
        pages = meta['totalPages'] as int;
        page++;
      } while (page <= pages);
      if (generation == _generation) entries = List.unmodifiable(rows);
    } catch (failure) {
      if (!_disposed && generation == _generation) {
        error = failure is ApiFailure
            ? failure.message
            : 'Could not load favorites. Try again.';
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> toggle(String id) async {
    if (_owner == null || loading || pending.contains(id) || _disposed) return;
    final owner = _owner;
    final saved = contains(id);
    pending.add(id);
    error = null;
    notifyListeners();
    try {
      await api.request(saved ? 'DELETE' : 'PUT', 'favorites/$id');
      if (!_disposed && owner == _owner) await load();
    } catch (failure) {
      if (!_disposed && owner == _owner) {
        error = failure is ApiFailure
            ? failure.message
            : 'Could not save this favorite. Try again.';
      }
    } finally {
      if (!_disposed && owner == _owner) {
        pending.remove(id);
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    auth.removeListener(_accountChanged);
    super.dispose();
  }
}
