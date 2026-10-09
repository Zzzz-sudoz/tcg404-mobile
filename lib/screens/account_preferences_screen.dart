import 'package:flutter/material.dart';
import '../services/account_preferences.dart';
import '../services/commerce_api.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';

class AccountPreferencesScreen extends StatefulWidget {
  const AccountPreferencesScreen({
    super.key,
    required this.api,
    required this.auth,
    this.payments = false,
  });
  final CommerceApi api;
  final AuthState auth;
  final bool payments;
  @override
  State<AccountPreferencesScreen> createState() =>
      _AccountPreferencesScreenState();
}

class _AccountPreferencesScreenState extends State<AccountPreferencesScreen> {
  SavedDetails? _details;
  String? _error;
  bool _busy = false;
  late final int _revision;
  final _form = GlobalKey<FormState>();
  Map<String, TextEditingController>? _draft;
  String _method = 'gcash', _brand = 'visa';
  String get _group => widget.payments ? 'payments' : 'addresses';
  List<Map<String, String>> get _rows => _details?[_group] ?? [];
  bool get _current =>
      mounted && widget.auth.revision == _revision && widget.auth.user != null;
  @override
  void initState() {
    super.initState();
    _revision = widget.auth.revision;
    widget.auth.addListener(_authChanged);
    _load();
  }

  void _authChanged() {
    if (!_current && mounted) {
      setState(() {
        _clearDraft();
        _details = null;
      });
    }
  }

  void _clearDraft() {
    for (final field in _draft?.values ?? <TextEditingController>[]) {
      field.dispose();
    }
    _draft = null;
  }

  @override
  void dispose() {
    widget.auth.removeListener(_authChanged);
    _clearDraft();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await loadPreferences(widget.api);
      if (_current) setState(() => _details = result);
    } catch (error) {
      _fail(error);
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  void _fail(Object error) {
    if (!_current) return;
    if (error is ApiFailure && error.statusCode == 401) {
      widget.auth.expire();
      return;
    }
    setState(
      () => _error = error is ApiFailure
          ? error.message
          : 'Saved details could not be loaded. Try again.',
    );
  }

  Future<void> _save(List<Map<String, String>> rows) async {
    if (_busy || !_current) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final latest = await loadPreferences(widget.api);
      if (!_current) return;
      latest[_group] = rows;
      await widget.api.request('PATCH', 'auth/preferences', body: latest);
      if (!_current) return;
      setState(() {
        _details = latest;
        _clearDraft();
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved.')));
      }
    } catch (error) {
      _fail(error);
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  void _edit([Map<String, String>? row]) {
    final blank = widget.payments
        ? {
            'id': preferenceId(),
            'label': '',
            'mobile': '',
            'holder': widget.auth.user!.name,
            'last4': '',
            'expiry': '',
          }
        : {
            'id': preferenceId(),
            'label': '',
            'name': widget.auth.user!.name,
            'email': widget.auth.user!.email,
            'phone': '',
            'address': '',
            'city': '',
            'province': '',
            'postalCode': '',
            'country': 'Philippines',
          };
    setState(() {
      _clearDraft();
      _draft = {
        for (final entry in {...blank, ...?row}.entries)
          entry.key: TextEditingController(text: entry.value),
      };
      _method = row?['method'] ?? 'gcash';
      _brand = row?['brand'] ?? 'visa';
      _error = null;
    });
  }

  String? _validate(String key, String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Complete this field.';
    final max = key == 'address'
        ? 500
        : key == 'email'
        ? 254
        : key == 'label'
        ? 40
        : key == 'phone'
        ? 30
        : 100;
    if (text.length > max) return 'Use at most $max characters.';
    if (key == 'email' &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
      return 'Enter a valid email.';
    }
    if (key == 'phone' &&
        (!RegExp(r'^[+\d ().-]+$').hasMatch(text) ||
            text.replaceAll(RegExp(r'\D'), '').length < 7)) {
      return 'Enter a valid phone number.';
    }
    if (key == 'address' && text.length < 5) return 'Enter a complete address.';
    if ((key == 'postalCode' || key == 'last4') &&
        !RegExp(r'^\d{4}$').hasMatch(text)) {
      return 'Enter four digits.';
    }
    if (key == 'mobile' && !RegExp(r'^(09\d{9}|\+639\d{9})$').hasMatch(text)) {
      return 'Enter a Philippine mobile number.';
    }
    if (key == 'expiry' && !RegExp(r'^(0[1-9]|1[0-2])/\d{2}$').hasMatch(text)) {
      return 'Use MM/YY.';
    }
    return null;
  }

  Widget _field(String key, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: _draft![key],
      enabled: !_busy,
      decoration: InputDecoration(labelText: label),
      validator: (v) => _validate(key, v),
      keyboardType: ['phone', 'mobile', 'last4', 'postalCode'].contains(key)
          ? TextInputType.phone
          : key == 'email'
          ? TextInputType.emailAddress
          : TextInputType.text,
    ),
  );
  void _submit() {
    if (!_form.currentState!.validate()) return;
    final keys = widget.payments
        ? _method == 'gcash'
              ? ['id', 'label', 'mobile']
              : ['id', 'label', 'holder', 'last4', 'expiry']
        : [
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
          ];
    final row = {
      for (final key in keys) key: _draft![key]!.text.trim(),
      if (widget.payments) 'method': _method,
      if (widget.payments && _method == 'card') 'brand': _brand,
    };
    _save(
      _rows.any((r) => r['id'] == row['id'])
          ? [
              for (final r in _rows)
                if (r['id'] == row['id']) row else r,
            ]
          : [..._rows, row],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_current) return const Text('Sign in to manage saved details.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.payments ? 'Payment methods.' : 'Delivery addresses.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 20),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: TcgColors.red)),
          TextButton(
            onPressed: _busy ? null : _load,
            child: const Text('Try again'),
          ),
        ],
        for (final row in _rows)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${row['label']}${identical(row, _rows.first) ? ' · Default' : ''}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    widget.payments
                        ? row['method'] == 'gcash'
                              ? 'GCash · ${row['mobile']}'
                              : '${row['brand']} •••• ${row['last4']}\n${row['holder']} · ${row['expiry']}'
                        : '${row['name']}\n${row['address']}\n${row['city']}, ${row['province']} ${row['postalCode']}\n${row['phone']}',
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: _busy ? null : () => _edit(row),
                        child: const Text('Edit'),
                      ),
                      if (!identical(row, _rows.first))
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _save([
                                  row,
                                  ..._rows.where((r) => r['id'] != row['id']),
                                ]),
                          child: const Text('Make default'),
                        ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _save(
                                _rows
                                    .where((r) => r['id'] != row['id'])
                                    .toList(),
                              ),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (_draft == null && _details != null)
          FilledButton(
            onPressed: _busy || _rows.length >= 5 ? null : () => _edit(),
            child: Text(
              'Add ${widget.payments ? 'payment method' : 'address'}',
            ),
          ),
        if (_rows.length >= 5)
          const Text('Five saved entries. Edit or remove one to add another.'),
        if (_draft != null)
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _field('label', 'Label'),
                if (widget.payments) ...[
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _method,
                    decoration: const InputDecoration(labelText: 'Method'),
                    items: const [
                      DropdownMenuItem(value: 'gcash', child: Text('GCash')),
                      DropdownMenuItem(
                        value: 'card',
                        child: Text('Credit / debit card'),
                      ),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _method = v!),
                  ),
                  const SizedBox(height: 16),
                  if (_method == 'gcash')
                    _field('mobile', 'GCash mobile number')
                  else ...[
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _brand,
                      decoration: const InputDecoration(
                        labelText: 'Card brand',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'visa', child: Text('Visa')),
                        DropdownMenuItem(
                          value: 'mastercard',
                          child: Text('Mastercard'),
                        ),
                        DropdownMenuItem(
                          value: 'card',
                          child: Text('Other card'),
                        ),
                      ],
                      onChanged: _busy ? null : (v) => _brand = v!,
                    ),
                    const SizedBox(height: 16),
                    _field('holder', 'Name on card'),
                    _field('last4', 'Last four digits'),
                    _field('expiry', 'Expiry (MM/YY)'),
                  ],
                ] else ...[
                  for (final entry in {
                    'name': 'Recipient name',
                    'email': 'Email',
                    'phone': 'Phone',
                    'address': 'Street address',
                    'city': 'City / municipality',
                    'province': 'Province',
                    'postalCode': 'Postal code',
                  }.entries)
                    _field(entry.key, entry.value),
                  const Text('Country · Philippines'),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: const Text('Save details'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => setState(_clearDraft),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
