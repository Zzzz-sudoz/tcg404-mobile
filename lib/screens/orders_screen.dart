import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/commerce_api.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/store_widgets.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    super.key,
    required this.api,
    required this.auth,
    this.onShop,
  });
  final CommerceApi api;
  final AuthState auth;
  final VoidCallback? onShop;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<StoreOrder> _orders = [];
  String? _identity, _error;
  int _revision = -1, _generation = 0, _page = 0, _totalPages = 1;
  bool _loading = false, _retryReset = true;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_authChanged);
    _identity = widget.auth.user?.id;
    _revision = widget.auth.revision;
    if (_identity != null) _load();
  }

  @override
  void didUpdateWidget(covariant OrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.auth != widget.auth || oldWidget.api != widget.api) {
      oldWidget.auth.removeListener(_authChanged);
      widget.auth.addListener(_authChanged);
      _revision = -1;
      _authChanged();
    }
  }

  void _authChanged() {
    if (_identity == widget.auth.user?.id &&
        _revision == widget.auth.revision) {
      return;
    }
    _generation++;
    setState(() {
      _identity = widget.auth.user?.id;
      _revision = widget.auth.revision;
      _orders = [];
      _page = 0;
      _totalPages = 1;
      _error = null;
      _loading = false;
    });
    if (_identity != null) _load();
  }

  bool _current(int generation) =>
      mounted &&
      generation == _generation &&
      _identity != null &&
      _identity == widget.auth.user?.id &&
      _revision == widget.auth.revision;

  Future<void> _load({bool reset = true}) async {
    if (_identity == null || (!reset && _loading)) return;
    final generation = ++_generation;
    final page = reset ? 1 : _page + 1;
    setState(() {
      _loading = true;
      _error = null;
      _retryReset = reset;
    });
    try {
      final response = await widget.api.request(
        'GET',
        'orders/my-orders',
        query: {'page': '$page', 'limit': '12'},
      );
      if (!_current(generation)) return;
      final data = response['data'];
      final meta = response['meta'];
      if (data is! List ||
          data.length > 12 ||
          meta is! Map<String, dynamic> ||
          meta['page'] != page ||
          meta['totalPages'] is! int ||
          (meta['totalPages'] as int) < 1 ||
          data.any((row) => row is! Map<String, dynamic>)) {
        throw const FormatException('Invalid order history.');
      }
      final orders = data
          .map((row) => StoreOrder.fromJson(row as Map<String, dynamic>))
          .toList();
      if (data.any((row) => row['userId'] != _identity)) {
        throw const FormatException('Invalid order owner.');
      }
      setState(() {
        _orders = reset ? orders : [..._orders, ...orders];
        _page = page;
        _totalPages = meta['totalPages'] as int;
      });
    } on ApiFailure catch (error) {
      if (!_current(generation)) return;
      if (error.statusCode == 401) {
        widget.auth.expire();
        return;
      }
      setState(() => _error = error.message);
    } catch (_) {
      if (_current(generation)) {
        setState(
          () => _error = 'Order history could not be loaded. Please retry.',
        );
      }
    } finally {
      if (_current(generation)) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    widget.auth.removeListener(_authChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your orders')),
    body: StoreBackdrop(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: _identity == null || widget.auth.user == null
                ? const StoreMessage(
                    title: 'Sign in to see your orders',
                    message: 'Your receipts are saved with your account.',
                    icon: Icons.receipt_long_outlined,
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      children: [
                        Text(
                          'The collection continues.',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Saved receipts and delivery updates.',
                          style: TextStyle(color: TcgColors.muted),
                        ),
                        const SizedBox(height: 24),
                        if (_orders.isEmpty && _loading)
                          const Padding(
                            padding: EdgeInsets.all(48),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_orders.isEmpty && _error == null)
                          StoreMessage(
                            title: 'No orders yet',
                            message: 'Find the next card for your collection.',
                            icon: Icons.receipt_long_outlined,
                            action: 'Back to shop',
                            onAction:
                                widget.onShop ??
                                () => Navigator.of(context).pop(),
                          ),
                        for (final order in _orders)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: TcgColors.surface.withValues(alpha: .94),
                              borderRadius: BorderRadius.circular(16),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => OrderDetailScreen(
                                      api: widget.api,
                                      auth: widget.auth,
                                      id: order.id,
                                      initial: order,
                                    ),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        order.orderNumber,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        order.items
                                            .map(
                                              (item) =>
                                                  '${item.quantity} × ${item.name}',
                                            )
                                            .join(', '),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 16),
                                      Wrap(
                                        spacing: 16,
                                        runSpacing: 8,
                                        children: [
                                          Text(
                                            order.createdAt
                                                .toLocal()
                                                .toIso8601String()
                                                .split('T')
                                                .first,
                                            style: const TextStyle(
                                              color: TcgColors.muted,
                                            ),
                                          ),
                                          Text(
                                            order.status,
                                            style: const TextStyle(
                                              color: TcgColors.lavender,
                                            ),
                                          ),
                                          Text(
                                            money(order.total),
                                            style: const TextStyle(
                                              color: TcgColors.yellow,
                                              fontWeight: FontWeight.w700,
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
                        if (_error != null) ...[
                          Text(
                            _error!,
                            style: const TextStyle(color: TcgColors.red),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: _loading
                                ? null
                                : () => _load(reset: _retryReset),
                            child: const Text('Retry'),
                          ),
                        ],
                        if (_orders.isNotEmpty && _loading)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        if (_orders.isNotEmpty &&
                            !_loading &&
                            _error == null &&
                            _page < _totalPages)
                          OutlinedButton(
                            onPressed: () => _load(reset: false),
                            child: const Text('Load more orders'),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    ),
  );
}
