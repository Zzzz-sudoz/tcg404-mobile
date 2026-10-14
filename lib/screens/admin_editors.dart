import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/commerce_api.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/store_widgets.dart';
import 'admin_workspace.dart';
import '../models/product.dart';

class AdminProductEditor extends StatefulWidget {
  const AdminProductEditor({
    super.key,
    required this.api,
    required this.auth,
    this.initial,
    this.inventory = false,
  });
  final CommerceApi api;
  final AuthState auth;
  final Map<String, dynamic>? initial;
  final bool inventory;
  @override
  State<AdminProductEditor> createState() => _AdminProductEditorState();
}

class _AdminProductEditorState extends State<AdminProductEditor> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  String _game = 'pokemon', _condition = 'Near mint';
  bool _active = true, _featured = false, _busy = false;
  String? _error;
  late String _baseline;
  bool _allowLeave = false;
  String get _snapshot => jsonEncode([
    for (final entry in _fields.entries) entry.value.text.trim(),
    _game,
    _condition,
    _active,
    _featured,
  ]);
  bool get _dirty => _snapshot != _baseline;
  @override
  void initState() {
    super.initState();
    final values = widget.initial ?? {};
    _fields = {
      for (final key in [
        'name',
        'slug',
        'sku',
        'setName',
        'cardNumber',
        'rarity',
        'cardType',
        'language',
        'finish',
        'imageUrl',
        'description',
        'price',
        'stock',
        'lowStockThreshold',
        'note',
      ])
        key: TextEditingController(
          text:
              '${values[key] ?? (key == 'language'
                      ? 'English'
                      : key == 'lowStockThreshold'
                      ? 2
                      : ['price', 'stock'].contains(key)
                      ? 0
                      : '')}',
        ),
    };
    _game = values['game'] ?? _game;
    _condition = values['condition'] ?? _condition;
    _active = values['isActive'] ?? true;
    _featured = values['isFeatured'] ?? false;
    _baseline = _snapshot;
    for (final field in _fields.values) {
      field.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title, textAlign: TextAlign.center),
          content: Text(message),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("Cancel"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ==
      true;

  void _close([bool? saved]) {
    setState(() => _allowLeave = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, saved);
    });
  }

  Future<void> _leave() async {
    if (_busy) return;
    if (!_dirty ||
        await _confirm(
          "Discard unsaved changes?",
          "Your product changes have not been saved.",
          "Discard changes",
        )) {
      if (mounted) _close();
    }
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy ||
        !_form.currentState!.validate() ||
        widget.auth.user?.role != 'admin') {
      return;
    }
    if (!_dirty &&
        widget.initial != null &&
        !await _confirm(
          "No changes detected",
          "This product has not changed. Save it anyway?",
          "Proceed",
        )) {
      return;
    }
    if (!mounted) return;
    final revision = widget.auth.revision;
    if (widget.inventory &&
        !await _confirm(
          "Save stock changes?",
          "Confirm the stock and threshold shown in this form.",
          "Confirm save",
        )) {
      return;
    }
    if (!mounted) return;
    if (!widget.inventory) {
      final preview = Product(
        id: widget.initial?['id'] ?? 'preview',
        name: _fields['name']!.text.trim(),
        slug: _fields['slug']!.text.trim(),
        game: _game,
        setName: _fields['setName']!.text.trim(),
        rarity: _fields['rarity']!.text.trim(),
        condition: _condition,
        stock: adminNumber(_fields['stock']!.text, whole: true)!.toInt(),
        price: adminNumber(_fields['price']!.text)!.toDouble(),
        imageUrl: _fields['imageUrl']!.text.trim(),
        isActive: _active,
      );
      setState(() => _busy = true);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Review product', textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          scrollable: true,
          content: SizedBox(
            width: 320,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: CardArtwork(product: preview),
                ),
                Text(
                  preview.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(preview.setName),
                Text('${preview.gameName} · ${preview.condition}'),
                const SizedBox(height: 12),
                Text(
                  money(preview.price),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text('${preview.stock} in stock'),
                Text(
                  _active
                      ? 'Active in store'
                      : 'Archived · hidden from the store',
                ),
                if (_featured) Text('Featured'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Back to edit'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Confirm save'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      setState(() => _busy = false);
      if (confirmed != true ||
          revision != widget.auth.revision ||
          widget.auth.user?.role != 'admin') {
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final values = <String, dynamic>{
        if (!widget.inventory) ...{
          for (final key in [
            'name',
            'slug',
            'sku',
            'setName',
            'cardNumber',
            'rarity',
            'cardType',
            'language',
            'finish',
            'imageUrl',
            'description',
          ])
            key: _fields[key]!.text.trim(),
          'game': _game,
          'condition': _condition,
          'price': adminNumber(_fields['price']!.text),
          'isActive': _active,
          'isFeatured': _featured,
        },
        'stock': adminNumber(_fields['stock']!.text, whole: true),
        'lowStockThreshold': adminNumber(
          _fields['lowStockThreshold']!.text,
          whole: true,
        ),
        if (widget.inventory) 'revision': widget.initial!['revision'],
        if (widget.inventory) 'note': _fields['note']!.text.trim(),
      };
      await widget.api.request(
        widget.inventory
            ? 'PATCH'
            : widget.initial == null
            ? 'POST'
            : 'PUT',
        widget.inventory
            ? 'admin/inventory/${widget.initial!['id']}'
            : widget.initial == null
            ? 'admin/products'
            : 'admin/products/${widget.initial!['id']}',
        body: values,
        revision: widget.inventory ? null : widget.initial?['revision'],
      );
      if (mounted && revision == widget.auth.revision) {
        _close(true);
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    String key,
    String label, {
    bool required = false,
    bool number = false,
    bool whole = false,
    int max = 200,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: TextFormField(
      controller: _fields[key],
      enabled: !_busy,
      decoration: InputDecoration(labelText: label),
      maxLength: max,
      maxLines: lines,
      keyboardType: number
          ? TextInputType.numberWithOptions(decimal: !whole)
          : lines > 1
          ? TextInputType.multiline
          : TextInputType.text,
      validator: (text) {
        final value = text?.trim() ?? '';
        if (required && value.isEmpty) return 'Enter $label.';
        if (number && adminNumber(value, whole: whole) == null) {
          return whole
              ? 'Enter a nonnegative whole number.'
              : 'Enter a nonnegative price.';
        }
        if (key == 'slug' &&
            value.isNotEmpty &&
            !RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(value)) {
          return 'Use lowercase letters, numbers and hyphens.';
        }
        if (key == 'imageUrl' &&
            value.isNotEmpty &&
            !RegExp(r'^https://[^\s]+$|^/(?!/)[\w/.-]+$').hasMatch(value)) {
          return 'Use an HTTPS URL or local path.';
        }
        return null;
      },
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.auth,
    builder: (context, child) => PopScope<bool>(
      canPop: _allowLeave || (!_dirty && !_busy),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.inventory
                ? 'Adjust stock'
                : widget.initial == null
                ? 'Add product'
                : 'Edit product',
          ),
        ),
        body: widget.auth.user?.role != 'admin'
            ? const Center(child: Text('Administrator access required.'))
            : StoreBackdrop(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Form(
                      key: _form,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          if (_error != null) ...[
                            Text(
                              _error!,
                              style: TextStyle(
                                color: TcgColors.of(context).red,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (widget.inventory) ...[
                            Text(
                              '${widget.initial!['name']}',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (!widget.inventory) ...[
                            _field('name', 'Name', required: true),
                            _field('slug', 'Slug'),
                            _field('sku', 'SKU', required: true, max: 120),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _game,
                              decoration: const InputDecoration(
                                labelText: 'Game',
                              ),
                              items: [
                                for (final game in [
                                  'pokemon',
                                  'one-piece',
                                  'magic',
                                ])
                                  DropdownMenuItem(
                                    value: game,
                                    child: Text(
                                      {
                                        'pokemon': 'Pokemon',
                                        'one-piece': 'One Piece',
                                        'magic': 'Magic: The Gathering',
                                      }[game]!,
                                    ),
                                  ),
                              ],
                              onChanged: _busy
                                  ? null
                                  : (value) => setState(() => _game = value!),
                            ),
                            const SizedBox(height: 20),
                            _field('setName', 'Set', required: true),
                            _field('cardNumber', 'Card number'),
                            _field('rarity', 'Rarity', required: true),
                            _field('cardType', 'Card type'),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _condition,
                              decoration: const InputDecoration(
                                labelText: 'Condition',
                              ),
                              items: [
                                for (final value in [
                                  'Near mint',
                                  'Lightly played',
                                  'Moderately played',
                                  'Heavily played',
                                  'Damaged',
                                ])
                                  DropdownMenuItem(
                                    value: value,
                                    child: Text(value),
                                  ),
                              ],
                              onChanged: _busy
                                  ? null
                                  : (value) =>
                                        setState(() => _condition = value!),
                            ),
                            const SizedBox(height: 20),
                            _field('language', 'Language'),
                            _field('finish', 'Finish'),
                            _field(
                              'price',
                              'Price (PHP)',
                              number: true,
                              required: true,
                            ),
                          ],
                          _field(
                            'stock',
                            'Stock',
                            number: true,
                            whole: true,
                            required: true,
                          ),
                          _field(
                            'lowStockThreshold',
                            'Low stock threshold',
                            number: true,
                            whole: true,
                            required: true,
                          ),
                          if (widget.inventory)
                            _field(
                              'note',
                              'Adjustment note',
                              max: 500,
                              lines: 3,
                            ),
                          if (!widget.inventory) ...[
                            _field(
                              'imageUrl',
                              'Artwork URL or path',
                              max: 2000,
                            ),
                            _field(
                              'description',
                              'Description',
                              max: 5000,
                              lines: 4,
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('Active in store'),
                              value: _active,
                              onChanged: _busy
                                  ? null
                                  : (value) => setState(() => _active = value),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('Featured'),
                              value: _featured,
                              onChanged: _busy
                                  ? null
                                  : (value) =>
                                        setState(() => _featured = value),
                            ),
                          ],
                          const SizedBox(height: 24),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              OutlinedButton(
                                onPressed: _busy ? null : _leave,
                                child: Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: _busy ? null : _save,
                                child: Text(
                                  _busy
                                      ? 'Saving...'
                                      : widget.inventory
                                      ? 'Save stock'
                                      : 'Save product',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    ),
  );
}

class AdminOrderScreen extends StatefulWidget {
  const AdminOrderScreen({
    super.key,
    required this.api,
    required this.auth,
    required this.id,
  });
  final CommerceApi api;
  final AuthState auth;
  final String id;
  @override
  State<AdminOrderScreen> createState() => _AdminOrderScreenState();
}

class _AdminOrderScreenState extends State<AdminOrderScreen> {
  late Future<Map<String, dynamic>> _response;
  String? _status, _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _status = null;
    _response = widget.api.request('GET', 'admin/orders/${widget.id}');
  }

  Future<void> _save(Map<String, dynamic> order) async {
    if (_busy || widget.auth.user?.role != 'admin') return;
    final revision = widget.auth.revision;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.request(
        'PATCH',
        'admin/orders/${widget.id}/status',
        body: {
          'revision': order['revision'],
          'status': _status ?? adminStatusOptions(order['status']).first,
        },
      );
      if (mounted && revision == widget.auth.revision) setState(_reload);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _section(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.auth,
    builder: (context, child) => Scaffold(
      appBar: AppBar(
        title: Text('Order details'),
        actions: [
          IconButton(
            tooltip: 'Reload order',
            onPressed: _busy ? null : () => setState(_reload),
            icon: Icon(Icons.refresh),
          ),
        ],
      ),
      body: widget.auth.user?.role != 'admin'
          ? const Center(child: Text('Administrator access required.'))
          : StoreBackdrop(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _response,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return StoreMessage(
                      title: 'Could not load order',
                      message: '${snapshot.error}',
                      action: 'Try again',
                      onAction: () => setState(_reload),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final order = snapshot.data!['data'] as Map<String, dynamic>,
                      shipping = order['shipping'] as Map;
                  final options = adminStatusOptions(order['status']);
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 850),
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          Text(
                            '${order['orderNumber']}',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 12),
                          Text(adminStatusLabel(order['status'])),
                          const SizedBox(height: 24),
                          _section('Order timeline', [
                            for (final event
                                in (order['statusHistory'] as List? ?? []))
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.check_circle_outline),
                                title: Text(
                                  adminStatusLabel(event['status'] as String),
                                ),
                                subtitle: Text(
                                  DateTime.tryParse(
                                        '${event['at']}',
                                      )?.toLocal().toString() ??
                                      '${event['at']}',
                                ),
                              ),
                            if ((order['statusHistory'] as List? ?? []).isEmpty)
                              Text('Created: ${order['createdAt']}'),
                          ]),
                          const SizedBox(height: 16),
                          _section('Customer', [
                            Text(
                              '${order['buyer']?['name'] ?? shipping['name']}',
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${order['buyer']?['email'] ?? shipping['email']}',
                            ),
                          ]),
                          const SizedBox(height: 16),
                          _section('Ordered singles', [
                            for (final item in order['items'])
                              Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item['name']}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${item['quantity']} × ${money((item['unitPrice'] as num).toDouble())} = ${money((item['lineTotal'] as num).toDouble())}',
                                    ),
                                  ],
                                ),
                              ),
                          ]),
                          const SizedBox(height: 16),
                          _section('Delivery address', [
                            for (final key in [
                              'name',
                              'email',
                              'phone',
                              'address',
                              'city',
                              'province',
                              'postalCode',
                              'country',
                              'notes',
                            ])
                              if (shipping[key] != null &&
                                  '${shipping[key]}'.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text('${shipping[key]}'),
                                ),
                          ]),
                          const SizedBox(height: 16),
                          _section('Receipt totals', [
                            for (final entry in {
                              'Subtotal': order['subtotal'],
                              'Shipping': order['shippingFee'],
                              'Tax': order['tax'],
                              'Total': order['total'],
                            }.entries)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  spacing: 20,
                                  runSpacing: 8,
                                  children: [
                                    Text(entry.key),
                                    Text(
                                      money((entry.value as num).toDouble()),
                                    ),
                                  ],
                                ),
                              ),
                            const Divider(),
                            const SizedBox(height: 16),
                            Text(
                              'Payment: ${order['paymentStatus'] == 'unpaid' ? 'Awaiting payment' : 'Confirmed'}',
                            ),
                            if (order['payment'] != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                '${order['payment']['brand']} •••• ${order['payment']['last4']}',
                              ),
                            ],
                          ]),
                          if (options.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _section('Update order status', [
                              if (_error != null) ...[
                                Text(
                                  _error!,
                                  style: TextStyle(
                                    color: TcgColors.of(context).red,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                key: ValueKey(order['revision']),
                                initialValue: _status ?? options.first,
                                decoration: const InputDecoration(
                                  labelText: 'Status',
                                ),
                                items: [
                                  for (final option in options)
                                    DropdownMenuItem(
                                      value: option,
                                      child: Text(adminStatusLabel(option)),
                                    ),
                                ],
                                onChanged: _busy
                                    ? null
                                    : (value) =>
                                          setState(() => _status = value),
                              ),
                              const SizedBox(height: 28),
                              Center(
                                child: FilledButton(
                                  onPressed: _busy ? null : () => _save(order),
                                  child: Text(
                                    _busy ? 'Saving...' : 'Save status',
                                  ),
                                ),
                              ),
                            ]),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    ),
  );
}

class AdminMovementsScreen extends StatefulWidget {
  const AdminMovementsScreen({
    super.key,
    required this.api,
    required this.auth,
  });
  final CommerceApi api;
  final AuthState auth;
  @override
  State<AdminMovementsScreen> createState() => _AdminMovementsScreenState();
}

class _AdminMovementsScreenState extends State<AdminMovementsScreen> {
  int _page = 1;
  late Future<Map<String, dynamic>> _response;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _response = widget.api.request(
      'GET',
      'admin/inventory/movements',
      query: {'page': '$_page', 'limit': '20'},
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.auth,
    builder: (context, child) => Scaffold(
      appBar: AppBar(title: Text('Stock history')),
      body: widget.auth.user?.role != 'admin'
          ? const Center(child: Text('Administrator access required.'))
          : FutureBuilder<Map<String, dynamic>>(
              future: _response,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return StoreMessage(
                    title: 'Could not load stock history',
                    message: '${snapshot.error}',
                    action: 'Try again',
                    onAction: () => setState(_reload),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final response = snapshot.data!,
                    rows = response['data'] as List,
                    meta = response['meta'] as Map;
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (rows.isEmpty) Text('No stock movements.'),
                    for (final row in rows)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${row['productName']}',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${row['type']} · ${row['stockBefore']} to ${row['stockAfter']}',
                              ),
                              const SizedBox(height: 8),
                              Text('${row['createdAt']}'),
                              if ('${row['note']}'.isNotEmpty)
                                Text('${row['note']}'),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          tooltip: 'Previous page',
                          onPressed: _page > 1
                              ? () => setState(() {
                                  _page--;
                                  _reload();
                                })
                              : null,
                          icon: Icon(Icons.chevron_left),
                        ),
                        Text('Page $_page of ${meta['totalPages']}'),
                        IconButton(
                          tooltip: 'Next page',
                          onPressed: _page < (meta['totalPages'] as num)
                              ? () => setState(() {
                                  _page++;
                                  _reload();
                                })
                              : null,
                          icon: Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
    ),
  );
}
