import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../services/commerce_api.dart';
import 'auth_state.dart';
import 'cart_state.dart';

class CheckoutState extends ChangeNotifier {
  CheckoutState({
    required this.api,
    required this.auth,
    required this.cart,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       ownerId = auth.user?.id;
  final CommerceApi api;
  final AuthState auth;
  final CartState cart;
  final FlutterSecureStorage _storage;
  final String? ownerId;
  bool ready = false, busy = false, uncertain = false, recoveryFailed = false;
  String? error;
  StoreOrder? receipt;
  String? _pendingKey;
  Map<String, dynamic>? _pendingBody;
  bool _disposed = false;
  bool get hasPending => _pendingKey != null;
  List<Map<String, dynamic>> get summaryItems => hasPending
      ? [
          for (final item in _pendingBody!['items'])
            {
              'id': item['productId'],
              'quantity': item['quantity'],
              'price': item['expectedPrice'],
              'name':
                  cart.lines
                      .where((line) => line.id == item['productId'])
                      .firstOrNull
                      ?.product
                      ?.name ??
                  'Saved card ${item['productId']}',
            },
        ]
      : [
          for (final line in cart.lines)
            {
              'id': line.id,
              'quantity': line.quantity,
              'price': line.product?.price ?? 0,
              'name': line.product?.name ?? 'Unavailable card',
            },
        ];
  int get summarySubtotalCents => summaryItems.fold(
    0,
    (total, item) =>
        total +
        priceToCents((item['price'] as num).toDouble()) *
            (item['quantity'] as int),
  );
  Map<String, String> get savedShipping =>
      Map<String, String>.from(_pendingBody?['shipping'] ?? <String, String>{});
  String get _storageKey =>
      'tcg404.checkout.${Uri.encodeComponent(api.baseUrl)}.$ownerId';
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static String _uuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final text = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${text.substring(0, 8)}-${text.substring(8, 12)}-${text.substring(12, 16)}-${text.substring(16, 20)}-${text.substring(20)}';
  }

  Future<void> restore() async {
    if (busy) return;
    busy = true;
    error = null;
    recoveryFailed = false;
    _notify();
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw != null) {
        if (raw.length > 100000) throw const FormatException();
        final saved = jsonDecode(raw);
        if (saved is! Map ||
            saved['version'] != 1 ||
            saved['userId'] != ownerId ||
            saved['key'] is! String ||
            !RegExp(r'^[a-f0-9-]{36}$').hasMatch(saved['key']) ||
            saved['body'] is! Map) {
          throw const FormatException();
        }
        final body = Map<String, dynamic>.from(saved['body']);
        final items = body['items'];
        final shipping = body['shipping'];
        if (items is! List ||
            items.isEmpty ||
            items.length > 50 ||
            shipping is! Map ||
            shipping.values.any((value) => value is! String)) {
          throw const FormatException();
        }
        for (final item in items) {
          if (item is! Map ||
              item['productId'] is! String ||
              item['quantity'] is! int ||
              item['quantity'] < 1 ||
              item['quantity'] > 999 ||
              item['expectedPrice'] is! num ||
              !(item['expectedPrice'] as num).isFinite ||
              item['expectedPrice'] < 0) {
            throw const FormatException();
          }
        }
        _pendingKey = saved['key'];
        _pendingBody = body;
        uncertain = true;
      }
    } catch (_) {
      recoveryFailed = true;
      error =
          'Your previous checkout could not be recovered. Retry recovery before placing an order.';
    } finally {
      ready = true;
      busy = false;
      _notify();
    }
  }

  Future<void> _clearPending() async {
    await _storage.delete(key: _storageKey);
    _pendingKey = null;
    _pendingBody = null;
    uncertain = false;
  }

  Future<StoreOrder?> submit(Map<String, String> shipping) async {
    if (busy || !ready || recoveryFailed) return null;
    if (ownerId == null || auth.user?.id != ownerId) {
      error = 'Sign in to continue with this checkout.';
      _notify();
      return null;
    }
    if (receipt != null) return receipt;
    busy = true;
    error = null;
    _notify();
    final revision = auth.revision;
    try {
      if (!hasPending) {
        final before = {
          for (final line in cart.lines) line.id: line.product?.price,
        };
        await cart.refresh();
        if (!cart.valid) {
          throw const ApiFailure(
            'Review availability in your cart before placing the order.',
            statusCode: 409,
            code: 'STOCK_CONFLICT',
          );
        }
        if (cart.lines.any((line) => before[line.id] != line.product?.price)) {
          throw const ApiFailure(
            'Prices updated. Review the summary, then place your order again.',
            statusCode: 409,
            code: 'PRICE_CHANGED',
          );
        }
        final body = <String, dynamic>{
          'items': [
            for (final line in cart.lines)
              {
                'productId': line.id,
                'quantity': line.quantity,
                'expectedPrice': line.product!.price,
              },
          ],
          'shipping': Map<String, String>.from(shipping),
        };
        final key = _uuid();
        await _storage.write(
          key: _storageKey,
          value: jsonEncode({
            'version': 1,
            'userId': ownerId,
            'key': key,
            'body': body,
          }),
        );
        _pendingKey = key;
        _pendingBody = body;
      }
      if (auth.user?.id != ownerId || auth.revision != revision) {
        throw const ApiFailure('Your session changed. Sign in again.');
      }
      final response = await api.request(
        'POST',
        'orders',
        body: _pendingBody,
        idempotencyKey: _pendingKey,
      );
      if (auth.user?.id != ownerId || auth.revision != revision) {
        throw const ApiFailure(
          'Your session changed. Sign in to check this submission.',
        );
      }
      final data = response['data'];
      if (data is! Map<String, dynamic> || data['userId'] != ownerId) {
        throw const ApiFailure(
          'The order confirmation could not be verified. Retry the same submission.',
        );
      }
      final order = StoreOrder.fromJson(data);
      final purchased = <String, int>{
        for (final item in _pendingBody!['items'])
          item['productId'] as String: item['quantity'] as int,
      };
      final cleared = await cart.completeOrder(order.id, purchased);
      receipt = order;
      if (cleared) {
        try {
          await _clearPending();
        } catch (_) {
          error =
              'Order placed. Its saved confirmation will be recovered on your next visit.';
        }
      } else {
        error =
            'Order placed, but the saved cart could not be updated. Your receipt is available in Orders.';
      }
      return order;
    } on ApiFailure catch (failure) {
      error = failure.message;
      uncertain =
          hasPending &&
          (failure.uncertain ||
              failure.statusCode == 401 ||
              failure.code == 'IDEMPOTENCY_CONFLICT');
      if (failure.statusCode == 401 && auth.revision == revision) auth.expire();
      if (hasPending && !uncertain) {
        try {
          await _clearPending();
        } catch (_) {
          uncertain = true;
          error =
              'The previous checkout is still saved. Retry the same submission.';
        }
        if (failure.code == 'PRICE_CHANGED' ||
            failure.code == 'STOCK_CONFLICT' ||
            failure.code == 'PRODUCT_UNAVAILABLE') {
          await cart.refresh();
        }
      }
    } catch (_) {
      uncertain = hasPending;
      error = hasPending
          ? 'Confirmation is unavailable. Retry the same submission or check your order history.'
          : 'Checkout could not be saved securely. Try again.';
    } finally {
      busy = false;
      _notify();
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
