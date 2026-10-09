import 'dart:math';
import 'commerce_api.dart';

typedef SavedDetails = Map<String, List<Map<String, String>>>;

Future<SavedDetails> loadPreferences(CommerceApi api) async {
  final response = await api.request('GET', 'auth/preferences');
  final data = response['data'];
  final value = data is Map ? data['preferences'] : null;
  if (value is! Map) throw const FormatException('Invalid saved details.');
  final result = <String, List<Map<String, String>>>{};
  for (final group in ['addresses', 'payments']) {
    final rows = value[group];
    if (rows is! List || rows.length > 5) {
      throw const FormatException('Invalid saved details.');
    }
    result[group] = [for (final row in rows) _entry(row, group)];
  }
  return result;
}

Map<String, String> _entry(dynamic row, String group) {
  if (row is! Map ||
      row.values.any((value) => value is! String || value.length > 500)) {
    throw const FormatException('Invalid saved details.');
  }
  final keys = group == 'addresses'
      ? [
          'id',
          'label',
          'name',
          'email',
          'phone',
          'address',
          'city',
          'province',
          'postalCode',
          'country',
        ]
      : row['method'] == 'gcash'
      ? ['id', 'label', 'method', 'mobile']
      : ['id', 'label', 'method', 'brand', 'last4', 'holder', 'expiry'];
  if (keys.any((key) => row[key] is! String) ||
      row.keys.any((key) => !keys.contains(key)) ||
      !RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(row['id'])) {
    throw const FormatException('Invalid saved details.');
  }
  if (group == 'payments' &&
      (row['method'] == 'gcash'
          ? !RegExp(r'^(09\d{9}|\+639\d{9})$').hasMatch(row['mobile'])
          : row['method'] != 'card' ||
                !['visa', 'mastercard', 'card'].contains(row['brand']) ||
                !RegExp(r'^\d{4}$').hasMatch(row['last4']) ||
                !RegExp(r'^(0[1-9]|1[0-2])/\d{2}$').hasMatch(row['expiry']))) {
    throw const FormatException('Invalid saved payment method.');
  }
  return {for (final key in keys) key: row[key] as String};
}

String preferenceId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final value = bytes.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-${value.substring(12, 16)}-${value.substring(16, 20)}-${value.substring(20)}';
}
