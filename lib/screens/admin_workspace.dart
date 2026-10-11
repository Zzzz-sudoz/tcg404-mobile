import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/commerce_api.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/store_widgets.dart';
import 'admin_editors.dart';

List<String> adminStatusOptions(String status) => switch (status) {
  'pending' || 'confirmed' => ['processing', 'shipped', 'cancelled', 'delayed'],
  'processing' => ['shipped', 'cancelled', 'delayed'],
  'shipped' => ['completed', 'delayed'],
  'delayed' => ['processing', 'shipped', 'cancelled'],
  _ => [],
};

String adminStatusLabel(String value) => switch (value) {
  'confirmed' || 'processing' => 'Processing',
  'shipped' => 'To be delivered',
  'cancelled' => 'Canceled',
  'pending' => 'Pending',
  'completed' => 'Delivered',
  'delayed' => 'Delayed',
  _ => value,
};

num? adminNumber(String text, {bool whole = false}) {
  final value = num.tryParse(text.trim());
  if (value == null ||
      !value.isFinite ||
      value < 0 ||
      value > 9007199254740991 ||
      (whole && value != value.roundToDouble())) {
    return null;
  }
  return whole ? value.toInt() : value;
}

class AdminWorkspace extends StatefulWidget {
  const AdminWorkspace({
    super.key,
    required this.api,
    required this.auth,
    required this.onStore,
  });
  final CommerceApi api;
  final AuthState auth;
  final VoidCallback onStore;
  @override
  State<AdminWorkspace> createState() => _AdminWorkspaceState();
}

class _AdminWorkspaceState extends State<AdminWorkspace> {
  static const _sections = [
    'Overview',
    'Products',
    'Orders',
    'Analytics',
    'Inventory',
  ];
  static const _icons = [
    Icons.dashboard_outlined,
    Icons.style_outlined,
    Icons.receipt_long_outlined,
    Icons.bar_chart,
    Icons.inventory_2_outlined,
  ];
  int _section = 0, _page = 1, _analyticsTab = 0;
  String _search = '', _status = '', _stock = 'all';
  DateTime? _from, _to;
  late Future<Map<String, dynamic>> _response;
  Future<Map<String, dynamic>>? _forecast;
  final _searchController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, String> get _dates => {
    if (_from != null) 'from': _from!.toIso8601String().substring(0, 10),
    if (_to != null) 'to': _to!.toIso8601String().substring(0, 10),
  };
  void _reload() {
    final path = [
      'admin/analytics',
      'admin/products',
      'admin/orders',
      'admin/analytics',
      'admin/inventory',
    ][_section];
    _response = widget.api.request(
      'GET',
      path,
      query: {
        if (_section == 0 || _section == 3 || _section == 2) ..._dates,
        if (_section != 0 && _section != 3) 'page': '$_page',
        if (_section != 0 && _section != 3) 'limit': '12',
        if (_search.isNotEmpty && _section != 0 && _section != 3)
          'search': _search,
        if (_section == 2 && _status.isNotEmpty) 'status': _status,
        if (_section == 4) 'stock': _stock,
      },
    );
    _forecast = _analyticsTab == 4
        ? widget.api.request('GET', 'admin/forecast')
        : null;
  }

  void _select(int index) => setState(() {
    _section = index;
    _page = 1;
    _search = '';
    _searchController.clear();
    _reload();
  });
  Future<void> _date(bool from) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (from ? _from : _to) ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null || !mounted) return;
    final start = from ? picked : _from, end = from ? _to : picked;
    if (start != null &&
        end != null &&
        (end.isBefore(start) || end.difference(start).inDays >= 366)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose an ordered range of at most 366 days.'),
        ),
      );
      return;
    }
    setState(() {
      _from = start;
      _to = end;
      _page = 1;
      _reload();
    });
  }

  Future<void> _logout() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.logout, color: TcgColors.red),
        title: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: TcgColors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) await widget.auth.logout();
  }

  Future<void> _edit(
    Map<String, dynamic>? row, {
    bool inventory = false,
  }) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminProductEditor(
          api: widget.api,
          auth: widget.auth,
          initial: row,
          inventory: inventory,
        ),
      ),
    );
    if (saved == true && mounted) setState(_reload);
  }

  Future<void> _order(Map<String, dynamic> row) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AdminOrderScreen(api: widget.api, auth: widget.auth, id: row['id']),
      ),
    );
    if (mounted) setState(_reload);
  }

  Widget _navigation({required bool wide}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'TCG404.',
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: TcgColors.yellow),
              ),
            ),
            for (var i = 0; i < _sections.length; i++)
              ListTile(
                selected: _section == i,
                leading: Icon(_icons[i]),
                title: Text(_sections[i]),
                onTap: () {
                  _select(i);
                  if (!wide) Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
      ListTile(
        leading: const Icon(Icons.storefront_outlined),
        title: const Text('Back to store'),
        onTap: widget.onStore,
      ),
      ListTile(
        leading: const Icon(Icons.logout, color: TcgColors.red),
        title: const Text('Logout', style: TextStyle(color: TcgColors.red)),
        onTap: widget.auth.busy ? null : _logout,
      ),
      const SizedBox(height: 20),
    ],
  );
  Widget _datesToolbar() => Wrap(
    spacing: 12,
    runSpacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      OutlinedButton(
        onPressed: () => _date(true),
        child: Text('From (UTC): ${_dates['from'] ?? 'Last 30 days'}'),
      ),
      OutlinedButton(
        onPressed: () => _date(false),
        child: Text('To (UTC): ${_dates['to'] ?? 'Today'}'),
      ),
      TextButton(
        onPressed: () => setState(() {
          _from = null;
          _to = null;
          _reload();
        }),
        child: const Text('Last 30 days'),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.auth,
    builder: (context, child) {
      if (widget.auth.user?.role != 'admin') {
        return const Scaffold(
          body: Center(child: Text('Administrator access required.')),
        );
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return Scaffold(
            appBar: AppBar(
              title: Text(_sections[_section]),
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () => setState(_reload),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            drawer: wide
                ? null
                : Drawer(child: SafeArea(child: _navigation(wide: false))),
            body: StoreBackdrop(
              child: SafeArea(
                child: Row(
                  children: [
                    if (wide)
                      SizedBox(
                        width: 235,
                        child: Material(
                          color: TcgColors.surface,
                          child: _navigation(wide: true),
                        ),
                      ),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.all(wide ? 32 : 20),
                        children: [
                          Text(
                            _sections[_section],
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 24),
                          if (_section == 0 ||
                              _section == 2 ||
                              _section == 3) ...[
                            _datesToolbar(),
                            const SizedBox(height: 24),
                          ],
                          if (_section == 1 ||
                              _section == 2 ||
                              _section == 4) ...[
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                labelText: _section == 2
                                    ? 'Search orders or buyers'
                                    : 'Search cards',
                                suffixIcon: IconButton(
                                  tooltip: 'Search',
                                  icon: const Icon(Icons.search),
                                  onPressed: () => setState(() {
                                    _page = 1;
                                    _search = _searchController.text.trim();
                                    _reload();
                                  }),
                                ),
                              ),
                              onSubmitted: (value) => setState(() {
                                _page = 1;
                                _search = value.trim();
                                _reload();
                              }),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_section == 1)
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: () => _edit(null),
                                icon: const Icon(Icons.add),
                                label: const Text('Add product'),
                              ),
                            ),
                          if (_section == 2)
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _status,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('All statuses'),
                                ),
                                for (final status in [
                                  'pending',
                                  'processing',
                                  'shipped',
                                  'delayed',
                                  'completed',
                                  'cancelled',
                                ])
                                  DropdownMenuItem(
                                    value: status,
                                    child: Text(adminStatusLabel(status)),
                                  ),
                              ],
                              onChanged: (value) => setState(() {
                                _status = value!;
                                _page = 1;
                                _reload();
                              }),
                            ),
                          if (_section == 4) ...[
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _stock,
                              decoration: const InputDecoration(
                                labelText: 'Stock',
                              ),
                              items: [
                                for (final status in ['all', 'low', 'out'])
                                  DropdownMenuItem(
                                    value: status,
                                    child: Text(
                                      {
                                        'all': 'All stock',
                                        'low': 'Low stock',
                                        'out': 'Out of stock',
                                      }[status]!,
                                    ),
                                  ),
                              ],
                              onChanged: (value) => setState(() {
                                _stock = value!;
                                _page = 1;
                                _reload();
                              }),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AdminMovementsScreen(
                                      api: widget.api,
                                      auth: widget.auth,
                                    ),
                                  ),
                                ),
                                child: const Text('Stock history'),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          FutureBuilder<Map<String, dynamic>>(
                            future: _response,
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return StoreMessage(
                                  title: 'Could not load workspace',
                                  message: '${snapshot.error}',
                                  action: 'Try again',
                                  onAction: () => setState(_reload),
                                );
                              }
                              if (snapshot.connectionState !=
                                      ConnectionState.done ||
                                  !snapshot.hasData) {
                                return const Padding(
                                  padding: EdgeInsets.all(48),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              final response = snapshot.data!,
                                  data = response['data'];
                              if (_section == 0 || _section == 3) {
                                return _analytics(
                                  Map<String, dynamic>.from(data),
                                );
                              }
                              final rows = (data as List)
                                  .cast<Map<String, dynamic>>();
                              final meta = response['meta'] as Map;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (rows.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.all(32),
                                      child: Text('No matching records.'),
                                    ),
                                  for (final row in rows)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16,
                                      ),
                                      child: _record(row),
                                    ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      IconButton(
                                        tooltip: 'Previous page',
                                        onPressed: _page > 1
                                            ? () => setState(() {
                                                _page--;
                                                _reload();
                                              })
                                            : null,
                                        icon: const Icon(Icons.chevron_left),
                                      ),
                                      Text(
                                        'Page ${meta['page']} of ${meta['totalPages']}',
                                      ),
                                      IconButton(
                                        tooltip: 'Next page',
                                        onPressed:
                                            _page < (meta['totalPages'] as num)
                                            ? () => setState(() {
                                                _page++;
                                                _reload();
                                              })
                                            : null,
                                        icon: const Icon(Icons.chevron_right),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
  Widget _record(Map<String, dynamic> row) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${row[_section == 2 ? 'orderNumber' : 'name']}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (_section == 2) ...[
            Text('${row['buyer']?['name'] ?? row['shipping']?['name'] ?? ''}'),
            Text(
              '${row['buyer']?['email'] ?? row['shipping']?['email'] ?? ''}',
            ),
            const SizedBox(height: 8),
            Text(
              '${adminStatusLabel(row['status'])} · ${money((row['total'] as num).toDouble())}',
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () => _order(row),
                child: const Text('View order'),
              ),
            ),
          ] else ...[
            Text('${row['setName']}'),
            const SizedBox(height: 8),
            Text(
              '${row['stock']} in stock · ${money((row['price'] as num).toDouble())}',
            ),
            if (row['isActive'] == false)
              const Text('Archived', style: TextStyle(color: TcgColors.red)),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () => _edit(row, inventory: _section == 4),
                child: Text(_section == 4 ? 'Adjust stock' : 'Edit product'),
              ),
            ),
          ],
        ],
      ),
    ),
  );
  Widget _metric(String label, String value, Color color) => Container(
    width: 230,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: .35)),
      color: color.withValues(alpha: .07),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 16),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(color: color),
        ),
      ],
    ),
  );
  Widget _analytics(Map<String, dynamic> data) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _metric(
            'Paid revenue',
            money((data['revenue'] as num).toDouble()),
            TcgColors.yellow,
          ),
          _metric(
            'Completed value',
            money((data['orderValue'] as num).toDouble()),
            const Color(0xff8ed8c2),
          ),
          _metric('Orders created', '${data['orders']}', TcgColors.lavender),
          if (_section == 0) ...[
            _metric('Units sold', '${data['unitsSold']}', TcgColors.yellow),
            _metric(
              'Low / out of stock',
              '${data['inventory']['lowStock']} / ${data['inventory']['outOfStock']}',
              TcgColors.red,
            ),
          ],
        ],
      ),
      const SizedBox(height: 28),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < 5; i++)
            ChoiceChip(
              label: Text(
                ['Sales', 'Games', 'Best sellers', 'Orders', 'Forecast'][i],
              ),
              selected: _analyticsTab == i,
              onSelected: (_) => setState(() {
                _analyticsTab = i;
                if (i == 4) {
                  _forecast ??= widget.api.request('GET', 'admin/forecast');
                }
              }),
            ),
        ],
      ),
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: switch (_analyticsTab) {
            0 => AdminSalesChart(
              rows: (data['trend'] as List).cast<Map<String, dynamic>>(),
            ),
            1 => Column(
              children: [
                for (final row in data['byGame'])
                  ListTile(
                    title: Text('${row['game']}'),
                    trailing: Text('${row['unitsSold']} units'),
                  ),
              ],
            ),
            2 => Column(
              children: [
                if ((data['topProducts'] as List).isEmpty)
                  const Text('No completed sales in this period.'),
                for (final row in data['topProducts'])
                  ListTile(
                    title: Text('${row['name']}'),
                    subtitle: Text('${row['unitsSold']} sold'),
                  ),
              ],
            ),
            3 => Column(
              children: [
                for (final entry in (data['statuses'] as Map).entries)
                  if (entry.key != 'confirmed')
                    ListTile(
                      title: Text(adminStatusLabel(entry.key)),
                      trailing: Text(
                        '${(entry.value as num) + (entry.key == 'processing' ? (data['statuses']['confirmed'] as num? ?? 0) : 0)}',
                      ),
                    ),
              ],
            ),
            _ => FutureBuilder<Map<String, dynamic>>(
              future: _forecast,
              builder: (context, snapshot) {
                if (snapshot.hasError) return Text('${snapshot.error}');
                if (snapshot.connectionState != ConnectionState.done ||
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final forecast = snapshot.data!['data'] as Map;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seven-day forecast',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 20),
                    for (final row in forecast['forecast'])
                      ListTile(
                        title: Text('${row['date']}'),
                        trailing: Text(money((row['value'] as num).toDouble())),
                      ),
                    for (final key in [
                      'fastMoving',
                      'slowMoving',
                      'lowStockRisks',
                    ]) ...[
                      const Divider(),
                      Text(
                        {
                          'fastMoving': 'Fast-moving singles',
                          'slowMoving': 'Slow-moving singles',
                          'lowStockRisks': 'Low-stock risks',
                        }[key]!,
                      ),
                      for (final row in forecast['insights']?[key] ?? [])
                        ListTile(
                          title: Text('${row['name']}'),
                          subtitle: Text('${row['stock']} in stock'),
                        ),
                    ],
                  ],
                );
              },
            ),
          },
        ),
      ),
    ],
  );
}

class AdminSalesChart extends StatelessWidget {
  const AdminSalesChart({super.key, required this.rows});
  final List<Map<String, dynamic>> rows;
  @override
  Widget build(BuildContext context) {
    final maximum = rows.fold<double>(
      1,
      (value, row) => math.max(value, (row['orderValue'] as num).toDouble()),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sales over time', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 24),
        SizedBox(
          height: 240,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final row in rows)
                  SizedBox(
                    width: 56,
                    child: Semantics(
                      label:
                          '${row['date']}: ${money((row['orderValue'] as num).toDouble())}',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            money((row['orderValue'] as num).toDouble()),
                            style: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 28,
                            height: math.max(
                              2,
                              175 *
                                  (row['orderValue'] as num).toDouble() /
                                  maximum,
                            ),
                            color: TcgColors.yellow,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${row['date']}'.substring(5),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Completed order value',
          style: const TextStyle(color: TcgColors.muted),
        ),
      ],
    );
  }
}
