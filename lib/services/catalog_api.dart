import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/product.dart';

export '../models/product.dart' show ProductPage;

class CatalogException implements Exception {
  const CatalogException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class CatalogApi {
  CatalogApi({
    String? baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client(),
       _base = Uri.parse(baseUrl ?? _defaultBaseUrl()) {
    if (!const ['http', 'https'].contains(_base.scheme) ||
        _base.host.isEmpty ||
        _base.userInfo.isNotEmpty ||
        _base.hasQuery ||
        _base.hasFragment) {
      throw const CatalogException('Invalid catalog address.');
    }
  }

  final http.Client _client;
  final Duration timeout;
  final Uri _base;
  String get baseUrl => _base.toString();
  static const _filters = {
    'search',
    'game',
    'set',
    'rarity',
    'condition',
    'minPrice',
    'maxPrice',
    'inStock',
    'sort',
    'page',
    'limit',
    'featured',
    'new',
  };

  static String _defaultBaseUrl() {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    if (kIsWeb) return '${Uri.base.origin}/api';
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:5000/api'
        : 'http://127.0.0.1:5000/api';
  }

  Uri _uri(List<String> suffix, Map<String, String> query) => _base.replace(
    pathSegments: [
      ..._base.pathSegments.where((part) => part.isNotEmpty),
      ...suffix,
    ],
    queryParameters: query.isEmpty ? null : query,
  );

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final abort = Completer<void>();
    try {
      final request = http.AbortableRequest(
        'GET',
        uri,
        abortTrigger: abort.future,
      )..headers['Accept'] = 'application/json';
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(
            timeout,
            onTimeout: () {
              abort.complete();
              throw TimeoutException('Catalog timed out');
            },
          );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CatalogException(
          response.statusCode == 404
              ? 'This card is no longer available.'
              : 'The catalog is unavailable. Try again.',
          statusCode: response.statusCode,
        );
      }
      if (response.bodyBytes.length > 4 * 1024 * 1024) {
        throw const FormatException();
      }
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is! Map<String, dynamic> || json['success'] != true) {
        throw const FormatException();
      }
      return json;
    } on TimeoutException {
      throw const CatalogException(
        'The catalog took too long to respond. Try again.',
      );
    } on http.ClientException {
      throw const CatalogException(
        'Could not connect to the catalog. Check your connection.',
      );
    } on FormatException {
      throw const CatalogException(
        'The catalog returned invalid information. Try again.',
      );
    }
  }

  Future<ProductPage> list([Map<String, String> query = const {}]) async {
    if (query.keys.any((key) => !_filters.contains(key))) {
      throw const CatalogException('Unsupported catalog filter.');
    }
    final json = await _get(_uri(['products'], query));
    try {
      final data = json['data'];
      final meta = json['meta'];
      if (data is! List || meta is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final total = meta['total'];
      final page = meta['page'];
      final pages = meta['totalPages'];
      final facets = meta['facets'];
      if (total is! int ||
          total < 0 ||
          page is! int ||
          page < 1 ||
          pages is! int ||
          pages < 1 ||
          page > pages ||
          facets is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final parsedFacets = <String, List<String>>{};
      for (final key in ['sets', 'rarities', 'conditions']) {
        final values = facets[key];
        if (values is! List || values.any((value) => value is! String)) {
          throw const FormatException();
        }
        parsedFacets[key] = values.cast<String>();
      }
      return ProductPage(
        items: data.map((item) {
          if (item is! Map<String, dynamic>) throw const FormatException();
          return Product.fromJson(item);
        }).toList(),
        total: total,
        page: page,
        totalPages: pages,
        facets: parsedFacets,
      );
    } on FormatException {
      throw const CatalogException(
        'The catalog returned invalid information. Try again.',
      );
    }
  }

  Future<Product> product(String idOrSlug) async {
    if (idOrSlug.trim().isEmpty || idOrSlug.length > 200) {
      throw const CatalogException('Choose a valid card.');
    }
    final json = await _get(_uri(['products', idOrSlug], const {}));
    try {
      final data = json['data'];
      if (data is! Map<String, dynamic>) throw const FormatException();
      return Product.fromJson(data);
    } on FormatException {
      throw const CatalogException(
        'The catalog returned invalid information. Try again.',
      );
    }
  }

  String imageUrl(String path) {
    final uri = Uri.tryParse(path);
    if (uri == null || path.isEmpty || uri.userInfo.isNotEmpty) return '';
    if (uri.hasScheme) {
      return const ['http', 'https'].contains(uri.scheme) && uri.host.isNotEmpty
          ? uri.toString()
          : '';
    }
    if (uri.hasAuthority) return '';
    return _base
        .replace(path: '/', query: null, fragment: null)
        .resolveUri(uri)
        .toString();
  }

  void close() => _client.close();
}
