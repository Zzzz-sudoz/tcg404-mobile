import 'dart:async';
import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/commerce_api.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/store_widgets.dart';
import '../widgets/order_status.dart';
import '../widgets/order_after_sales.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.api,
    required this.auth,
    required this.id,
    this.initial,
    this.success = false,
    this.onShop,
  });
  final CommerceApi api;
  final AuthState auth;
  final String id;
  final StoreOrder? initial;
  final bool success;
  final VoidCallback? onShop;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen>
    with WidgetsBindingObserver {
  StoreOrder? _order;
  String? _identity, _error;
  int _revision = -1, _generation = 0;
  bool _loading = false;
  Timer? _timer;
  bool get _visible =>
      mounted &&
      ModalRoute.of(context)?.isCurrent == true &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _visible && !_loading) _load();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_visible && !_loading) _load();
    });
    _identity = widget.auth.user?.id;
    _revision = widget.auth.revision;
    if (_identity != null &&
        widget.success &&
        widget.initial?.id == widget.id) {
      _order = widget.initial;
    }
    widget.auth.addListener(_authChanged);
    if (_identity != null) _load();
  }

  @override
  void didUpdateWidget(covariant OrderDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.auth != widget.auth ||
        oldWidget.api != widget.api ||
        oldWidget.id != widget.id) {
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
      _order = null;
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

  Future<void> _load() async {
    if (_identity == null || _loading) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await widget.api.request(
        'GET',
        'orders/${Uri.encodeComponent(widget.id)}',
      );
      if (!_current(generation)) return;
      final data = response['data'];
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Invalid receipt.');
      }
      final order = StoreOrder.fromJson(data);
      if (order.id != widget.id) {
        throw const FormatException('Invalid receipt.');
      }
      if (data['userId'] != null && data['userId'] != _identity) {
        throw const FormatException('Invalid receipt owner.');
      }
      setState(() => _order = order);
    } on ApiFailure catch (error) {
      if (!_current(generation)) return;
      if (error.statusCode == 401) {
        widget.auth.expire();
        return;
      }
      setState(() {
        if (error.statusCode != null && error.statusCode! < 500) _order = null;
        _error = error.message;
      });
    } catch (_) {
      if (_current(generation)) {
        setState(() {
          _error = 'This receipt could not be loaded. Please retry.';
        });
      }
    } finally {
      if (_current(generation)) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    widget.auth.removeListener(_authChanged);
    super.dispose();
  }

  Widget _amount(String label, double value, {bool total = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: total
                  ? TcgColors.of(context).ink
                  : TcgColors.of(context).muted,
              fontWeight: total ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            money(value),
            textAlign: TextAlign.end,
            style: TextStyle(
              color: total
                  ? TcgColors.of(context).yellow
                  : TcgColors.of(context).ink,
              fontSize: total ? 24 : 14,
              fontWeight: total ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _art(OrderItem item) {
    final fallback = Icon(
      Icons.style_outlined,
      color: TcgColors.of(context).muted,
    );
    final path = item.imageUrl;
    Widget image;
    if (RegExp(r'^/cards/[a-zA-Z0-9_.-]+$').hasMatch(path)) {
      image = Image.asset(
        'assets/cards/${path.split('/').last}',
        fit: BoxFit.contain,
        errorBuilder: (_, error, stack) => fallback,
        excludeFromSemantics: true,
      );
    } else if (Uri.tryParse(path)?.scheme == 'https') {
      image = Image.network(
        path,
        fit: BoxFit.contain,
        errorBuilder: (_, error, stack) => fallback,
        excludeFromSemantics: true,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      );
    } else {
      image = fallback;
    }
    return SizedBox(width: 64, height: 90, child: image);
  }

  Widget _receipt(StoreOrder order) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (widget.success) ...[
        Icon(
          Icons.check_circle_outline,
          color: TcgColors.of(context).yellow,
          size: 44,
        ),
        const SizedBox(height: 16),
        Text(
          'Order placed successfully.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Your cards are on the list. Keep this receipt for your records.',
          style: TextStyle(color: TcgColors.of(context).muted),
        ),
        const SizedBox(height: 28),
      ],
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: TcgColors.of(context).surface.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: TcgColors.of(context).border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order number',
              style: TextStyle(color: TcgColors.of(context).muted),
            ),
            const SizedBox(height: 8),
            SelectableText(
              order.orderNumber,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              order.createdAt.toLocal().toIso8601String().split('T').first,
              style: TextStyle(color: TcgColors.of(context).muted),
            ),
            const SizedBox(height: 12),
            Text(
              'Order status: ${order.statusLabel}',
              style: TextStyle(
                color: orderStatusColor(order.status, context: context),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Order timeline',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            for (final event in order.timeline)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 20,
                      color: orderStatusColor(event.status, context: context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.status == 'pending'
                                ? 'Order placed'
                                : event.label,
                            style: TextStyle(
                              color: orderStatusColor(
                                event.status,
                                context: context,
                              ),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            event.at
                                .toLocal()
                                .toIso8601String()
                                .replaceFirst('T', ' ')
                                .split('.')
                                .first,
                            style: TextStyle(
                              color: TcgColors.of(context).muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text('Payment: ${order.paymentLabel}'),
            if (order.payment != null) ...[
              const SizedBox(height: 12),
              Text(
                '${order.payment!['brand']} •••• ${order.payment!['last4']}',
              ),
              const SizedBox(height: 4),
              SelectableText(
                '${order.payment!['reference']}',
                style: TextStyle(color: TcgColors.of(context).muted),
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Divider(),
            ),
            Text(
              'Purchased cards',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _art(item),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.setName} · ${item.condition}',
                            style: TextStyle(
                              color: TcgColors.of(context).muted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('${item.quantity} × ${money(item.unitPrice)}'),
                          Text(
                            money(item.lineTotal),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Divider(),
            ),
            Text('Deliver to', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(
              order.shipping['name']!,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(order.shipping['address']!),
            if ([
              'city',
              'province',
              'postalCode',
              'country',
            ].any((key) => (order.shipping[key] ?? '').isNotEmpty))
              Text(
                ['city', 'province', 'postalCode', 'country']
                    .map((key) => order.shipping[key] ?? '')
                    .where((part) => part.isNotEmpty)
                    .join(', '),
              ),
            const SizedBox(height: 8),
            Text(order.shipping['phone']!),
            Text(order.shipping['email']!),
            if ((order.shipping['notes'] ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Delivery notes: ${order.shipping['notes']}'),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Divider(),
            ),
            _amount('Subtotal', order.subtotal),
            _amount('Shipping', order.shippingFee),
            _amount('Tax', order.tax),
            const SizedBox(height: 8),
            _amount('Total · ${order.currency}', order.total, total: true),
          ],
        ),
      ),
      if (widget.onShop != null)
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.onShop,
              child: const Text('Back to shop'),
            ),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.success ? 'Your receipt' : 'Order details'),
      actions: [
        IconButton(
          tooltip: 'Refresh order',
          onPressed: _loading || _identity == null ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: StoreBackdrop(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: _identity == null || widget.auth.user == null
                ? const StoreMessage(
                    title: 'Sign in to view this receipt',
                    message:
                        'Receipts are private to the account that placed the order.',
                    icon: Icons.receipt_long_outlined,
                  )
                : _order == null
                ? _loading
                      ? const Center(child: CircularProgressIndicator())
                      : StoreMessage(
                          title: 'Receipt unavailable',
                          message: _error ?? 'Please retry.',
                          action: 'Retry',
                          onAction: _load,
                          icon: Icons.receipt_long_outlined,
                        )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                      children: [
                        SizedBox(
                          height: 4,
                          child: _loading
                              ? const LinearProgressIndicator()
                              : null,
                        ),
                        if (_error != null) ...[
                          Text(
                            _error!,
                            style: TextStyle(color: TcgColors.of(context).red),
                          ),
                          OutlinedButton(
                            onPressed: _loading ? null : _load,
                            child: const Text('Retry receipt update'),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _receipt(_order!),
                        OrderAfterSales(
                          order: _order!,
                          api: widget.api,
                          auth: widget.auth,
                          refresh: _load,
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
