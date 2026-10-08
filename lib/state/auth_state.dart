import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/store_user.dart';
import '../services/commerce_api.dart';

class AuthState extends ChangeNotifier {
  AuthState({required this._api});
  final CommerceApi _api;
  StoreUser? user;
  bool ready = false, busy = false, restoreFailed = false;
  String? error;
  Map<String, String> fields = const {};
  int revision = 0;

  StoreUser _parse(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map || data['user'] is! Map) {
      throw const FormatException('Account response is invalid.');
    }
    return StoreUser.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }

  void _begin() {
    busy = true;
    error = null;
    fields = const {};
    notifyListeners();
  }

  void _failure(Object failure) {
    error = failure is ApiFailure
        ? failure.message
        : 'Account request failed. Please try again.';
    fields = failure is ApiFailure ? failure.fields : const {};
  }

  void _signedOut() {
    user = null;
    revision++;
    ready = true;
    restoreFailed = false;
  }

  void expire() {
    _signedOut();
    error = 'Your session expired. Sign in to continue.';
    fields = const {};
    unawaited(_api.clearSession().catchError((Object _) {}));
    notifyListeners();
  }

  Future<void> restore() async {
    if (busy) return;
    _begin();
    final started = revision;
    try {
      final restored = _parse(await _api.request('GET', 'auth/me'));
      if (started != revision) return;
      if (user?.id != restored.id) revision++;
      user = restored;
      restoreFailed = false;
    } catch (failure) {
      if (started != revision) return;
      if (failure is ApiFailure && failure.statusCode == 401) {
        _signedOut();
        unawaited(_api.clearSession().catchError((Object _) {}));
      } else {
        _failure(failure);
        restoreFailed = true;
      }
    } finally {
      ready = true;
      busy = false;
      notifyListeners();
    }
  }

  Future<String?> _save(
    String method,
    String path,
    Map<String, dynamic> body, {
    bool authenticating = false,
  }) async {
    if (busy) return 'An account request is already in progress.';
    _begin();
    final started = revision;
    try {
      final saved = _parse(await _api.request(method, path, body: body));
      if (started != revision) {
        await _api.clearSession().catchError((Object _) {});
        return 'Your session changed. Please sign in again.';
      }
      if (authenticating || user?.id != saved.id) revision++;
      user = saved;
      ready = true;
      restoreFailed = false;
      return null;
    } catch (failure) {
      if (started != revision) {
        return 'Your session changed. Please sign in again.';
      }
      if (!authenticating &&
          failure is ApiFailure &&
          failure.statusCode == 401) {
        expire();
      }
      _failure(failure);
      return error;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<String?> login(String email, String password) => _save(
    'POST',
    'auth/login',
    {'email': email.trim(), 'password': password},
    authenticating: true,
  );
  Future<String?> register(String name, String email, String password) => _save(
    'POST',
    'auth/register',
    {'name': name.trim(), 'email': email.trim(), 'password': password},
    authenticating: true,
  );
  Future<String?> updateName(String name) =>
      _save('PATCH', 'auth/profile', {'name': name.trim()});

  Future<void> logout() async {
    if (busy) return;
    _begin();
    final started = revision;
    try {
      await _api.request('POST', 'auth/logout');
      if (started != revision) return;
      _signedOut();
      await _api.clearSession();
    } catch (failure) {
      if (started == revision || user == null) _failure(failure);
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
