import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session_client_native.dart'
    if (dart.library.js_interop) 'session_client_web.dart';

class ApiFailure implements Exception {
  const ApiFailure(
    this.message, {
    this.code = 'REQUEST_FAILED',
    this.statusCode,
    this.fields = const {},
  });
  final String message, code;
  final int? statusCode;
  final Map<String, String> fields;
  bool get uncertain => statusCode == null || statusCode! >= 500;
  @override
  String toString() => message;
}

class CommerceApi {
  CommerceApi({required String baseUrl, http.Client? client})
    : _base = Uri.parse(baseUrl) {
    if (!['http', 'https'].contains(_base.scheme) ||
        _base.host.isEmpty ||
        _base.userInfo.isNotEmpty ||
        _base.hasQuery ||
        _base.hasFragment) {
      throw const ApiFailure('Invalid API address.');
    }
    _client = client ?? createSessionClient(_base);
  }
  final Uri _base;
  String get baseUrl => _base.toString();
  late final http.Client _client;
  static const _messages = {
    'UNAUTHORIZED': 'Your session ended. Sign in to continue.',
    'INVALID_CREDENTIALS': 'Email or password is incorrect.',
    'EMAIL_IN_USE': 'An account with this email already exists.',
    'VALIDATION_ERROR': 'Check the details below and try again.',
    'FORBIDDEN': 'You do not have access to this action.',
    'ORDER_NOT_FOUND': 'This order could not be found.',
    'PRICE_CHANGED':
        'A price changed. Review your cart before placing the order.',
    'STOCK_CONFLICT':
        'Stock changed. Review the available quantities in your cart.',
    'PRODUCT_UNAVAILABLE': 'A card is no longer available. Review your cart.',
    'IDEMPOTENCY_CONFLICT':
        'This submission differs from its original order. Check your order history.',
    'DATABASE_UNAVAILABLE': 'The store is temporarily unavailable. Try again.',
    'AUTH_RATE_LIMIT': 'Too many attempts. Please try again shortly.',
    'PRODUCT_CONFLICT': 'This product changed. Reload it before saving.',
    'ORDER_CONFLICT': 'This order changed. Reload it before saving.',
  };
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String> query = const {},
    String? idempotencyKey,
    int? revision,
  }) async {
    if (path.startsWith('/') ||
        path.contains('..') ||
        path.contains('?') ||
        !['GET', 'POST', 'PATCH', 'PUT'].contains(method)) {
      throw const ApiFailure('Invalid API request.');
    }
    final uri = _base.replace(
      pathSegments: [
        ..._base.pathSegments.where((part) => part.isNotEmpty),
        ...path.split('/'),
      ],
      queryParameters: query.isEmpty ? null : query,
    );
    try {
      final abort = Completer<void>();
      final request = http.AbortableRequest(
        method,
        uri,
        abortTrigger: abort.future,
      )..headers['Accept'] = 'application/json';
      if (method != 'GET') request.headers['Content-Type'] = 'application/json';
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      if (idempotencyKey != null) {
        request.headers['Idempotency-Key'] = idempotencyKey;
      }
      if (revision != null) request.headers['If-Match'] = '$revision';
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              abort.complete();
              throw TimeoutException('Request timed out.');
            },
          );
      Map<String, dynamic>? decoded;
      if (response.bodyBytes.length <= 2 * 1024 * 1024) {
        try {
          final value = jsonDecode(utf8.decode(response.bodyBytes));
          if (value is Map<String, dynamic>) decoded = value;
        } catch (_) {}
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded?['error'];
        final code = error is Map && error['code'] is String
            ? error['code'] as String
            : 'REQUEST_FAILED';
        final fields = <String, String>{};
        if (code == 'VALIDATION_ERROR' &&
            error is Map &&
            error['fields'] is Map) {
          for (final key in (error['fields'] as Map).keys) {
            if (key is String &&
                RegExp(r'^[a-zA-Z0-9.]{1,80}$').hasMatch(key)) {
              fields[key] = 'Check this value.';
            }
          }
        }
        throw ApiFailure(
          _messages[code] ?? 'The request could not be completed. Try again.',
          code: code,
          statusCode: response.statusCode,
          fields: fields,
        );
      }
      if (decoded == null ||
          decoded['success'] != true ||
          !decoded.containsKey('data')) {
        throw const ApiFailure(
          'The store returned an incomplete response. Try again.',
        );
      }
      return decoded;
    } on ApiFailure {
      rethrow;
    } on TimeoutException {
      throw ApiFailure(
        path == 'orders' && method == 'POST'
            ? 'The request took too long. Retry to check the same submission.'
            : 'The request took too long. Please try again.',
      );
    } on http.ClientException {
      throw const ApiFailure(
        'Could not connect securely to the store. Check your connection.',
      );
    } on FormatException {
      throw const ApiFailure(
        'The store returned invalid information. Try again.',
      );
    }
  }

  Future<void> clearSession() => clearClientSession(_client);
  void close() => _client.close();
}
