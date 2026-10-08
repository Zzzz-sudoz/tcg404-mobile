import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

NativeSessionClient createSessionClient(Uri baseUrl) =>
    NativeSessionClient(baseUrl: baseUrl);
Future<void> clearClientSession(http.Client client) async {
  if (client is NativeSessionClient) await client.clearSession();
}

class NativeSessionClient extends http.BaseClient {
  NativeSessionClient({
    required this.baseUrl,
    http.Client? client,
    FlutterSecureStorage? storage,
  }) : _client = client ?? http.Client(),
       _storage = storage ?? const FlutterSecureStorage();
  final Uri baseUrl;
  final http.Client _client;
  final FlutterSecureStorage _storage;
  String? _cookie;
  DateTime? _expires;
  bool _loaded = false;
  int _generation = 0;
  Future<void> _writes = Future.value();
  Future<void> _persist(Future<void> Function() action) {
    final next = _writes.then((_) => action());
    _writes = next.catchError((Object _) {});
    return next;
  }

  String get _key =>
      'tcg404.session.${Uri.encodeComponent('${baseUrl.origin}${baseUrl.path}')}';
  Future<void> clearSession() async {
    _generation++;
    _loaded = true;
    _cookie = null;
    _expires = null;
    await _persist(() => _storage.delete(key: _key));
  }

  Future<void> _load() async {
    if (_loaded) return;
    final raw = await _storage.read(key: _key);
    if (raw != null) {
      try {
        final value = jsonDecode(raw);
        final cookie = value['cookie'];
        final expires = DateTime.parse(value['expires']);
        if (cookie is! String ||
            !RegExp(
              r'^tcg404_session=[A-Za-z0-9._~-]{1,4096}$',
            ).hasMatch(cookie) ||
            !expires.isAfter(DateTime.now())) {
          await clearSession();
        } else {
          _cookie = cookie;
          _expires = expires;
        }
      } catch (_) {
        await clearSession();
      }
    }
    _loaded = true;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final prefix = '${baseUrl.path.replaceAll(RegExp(r'/+$'), '')}/';
    if (request.url.origin != baseUrl.origin ||
        !request.url.path.startsWith(prefix) ||
        request.url.userInfo.isNotEmpty) {
      throw http.ClientException('Invalid API address.');
    }
    try {
      await _load();
      if (_expires != null && !_expires!.isAfter(DateTime.now())) {
        await clearSession();
      }
      request.followRedirects = false;
      request.headers.remove('cookie');
      if (_cookie != null) request.headers['cookie'] = _cookie!;
      final changesSession =
          request.url.path.endsWith('/auth/login') ||
          request.url.path.endsWith('/auth/register') ||
          request.url.path.endsWith('/auth/logout');
      if (changesSession) _generation++;
      final generation = _generation;
      var aborted = false;
      if (request is http.Abortable) {
        request.abortTrigger?.then((_) {
          aborted = true;
        });
      }
      final response = await _client.send(request);
      if (aborted || generation != _generation) return response;
      final setCookie = response.headers['set-cookie'];
      if (setCookie != null) {
        final match = RegExp(
          r'(?:^|,\s*)tcg404_session=([A-Za-z0-9._~-]{0,4096})(?:;|$)',
        ).firstMatch(setCookie);
        if (match != null) {
          final age =
              int.tryParse(
                RegExp(
                      r'max-age=(\d+)',
                      caseSensitive: false,
                    ).firstMatch(setCookie)?.group(1) ??
                    '',
              ) ??
              3600;
          if (match.group(1)!.isEmpty || age == 0) {
            await clearSession();
          } else {
            final cookie = 'tcg404_session=${match.group(1)}';
            final expires = DateTime.now().add(
              Duration(seconds: age.clamp(0, 3600)),
            );
            await _persist(() async {
              if (aborted || generation != _generation) return;
              await _storage.write(
                key: _key,
                value: jsonEncode({
                  'cookie': cookie,
                  'expires': expires.toUtc().toIso8601String(),
                }),
              );
              if (!aborted && generation == _generation) {
                _cookie = cookie;
                _expires = expires;
              }
            });
          }
        }
      }
      if (response.statusCode == 401 &&
          generation == _generation &&
          !request.url.path.endsWith('/auth/login') &&
          !request.url.path.endsWith('/auth/register')) {
        try {
          await clearSession();
        } catch (_) {
          _cookie = null;
          _expires = null;
        }
      }
      return response;
    } on http.ClientException {
      rethrow;
    } catch (_) {
      throw http.ClientException(
        'The secure session could not be accessed. Try again.',
      );
    }
  }

  @override
  void close() => _client.close();
}
