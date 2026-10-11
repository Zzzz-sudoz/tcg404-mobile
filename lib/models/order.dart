import 'product.dart';
import 'return_request.dart';

const orderStatusLabels = {
  'pending': 'Pending',
  'confirmed': 'Confirmed',
  'processing': 'Processing',
  'shipped': 'To be delivered',
  'completed': 'Delivered',
  'cancelled': 'Canceled',
  'delayed': 'Delayed',
};

class OrderStatusEvent {
  const OrderStatusEvent({required this.status, required this.at});
  final String status;
  final DateTime at;
  String get label => orderStatusLabels[status]!;

  factory OrderStatusEvent.fromJson(Map<String, dynamic> json) {
    final status = _text(json, 'status');
    final at = DateTime.tryParse(_text(json, 'at'));
    if (!orderStatusLabels.containsKey(status) || at == null) {
      throw const FormatException('Invalid order update.');
    }
    return OrderStatusEvent(status: status, at: at);
  }
}

String _text(Map<String, dynamic> json, String key, {bool optional = false}) {
  final value = json[key] ?? (optional ? '' : null);
  if (value is! String ||
      value.length > 2000 ||
      (!optional && value.trim().isEmpty)) {
    throw const FormatException('Invalid order information.');
  }
  return value;
}

double _money(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num) throw const FormatException('Invalid order amount.');
  priceToCents(value.toDouble());
  return value.toDouble();
}

class OrderItem {
  const OrderItem({
    required this.productId,
    required this.name,
    required this.game,
    required this.setName,
    required this.condition,
    required this.imageUrl,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String productId, name, game, setName, condition, imageUrl;
  final int quantity;
  final double unitPrice, lineTotal;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final quantity = json['quantity'];
    final game = _text(json, 'game');
    if (quantity is! int ||
        quantity < 1 ||
        quantity > 999 ||
        !const ['pokemon', 'one-piece', 'magic'].contains(game)) {
      throw const FormatException('Invalid order item.');
    }
    return OrderItem(
      productId: _text(json, 'productId'),
      name: _text(json, 'name'),
      game: game,
      setName: _text(json, 'setName'),
      condition: _text(json, 'condition'),
      imageUrl: _text(json, 'imageUrl', optional: true),
      quantity: quantity,
      unitPrice: _money(json, 'unitPrice'),
      lineTotal: _money(json, 'lineTotal'),
    );
  }
}

class StoreOrder {
  StoreOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentStatus,
    required this.currency,
    required List<OrderItem> items,
    required Map<String, String> shipping,
    required this.subtotal,
    required this.shippingFee,
    required this.tax,
    required this.total,
    required this.createdAt,
    this.updatedAt,
    this.revision = 0,
    this.canCancel = false,
    this.canReturn = false,
    this.returnRequest,
    List<OrderStatusEvent>? statusHistory,
    Map<String, dynamic>? payment,
  }) : items = List.unmodifiable(items),
       shipping = Map.unmodifiable(shipping),
       payment = payment == null ? null : Map.unmodifiable(payment),
       timeline = List.unmodifiable(
         statusHistory != null && statusHistory.isNotEmpty
             ? statusHistory
             : [
                 OrderStatusEvent(status: 'pending', at: createdAt),
                 if (status != 'pending' && updatedAt != null)
                   OrderStatusEvent(status: status, at: updatedAt),
               ],
       );

  final String id, orderNumber, status, paymentStatus, currency;
  final List<OrderItem> items;
  final Map<String, String> shipping;
  final double subtotal, shippingFee, tax, total;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int revision;
  final bool canCancel, canReturn;
  final ReturnRequest? returnRequest;
  final List<OrderStatusEvent> timeline;
  final Map<String, dynamic>? payment;
  String get paymentLabel => paymentStatus == 'simulated'
      ? 'Confirmed'
      : paymentStatus == 'paid'
      ? 'Paid'
      : 'Awaiting payment';

  String get statusLabel => orderStatusLabels[status]!;

  factory StoreOrder.fromJson(Map<String, dynamic> json) {
    final rows = json['items'];
    final address = json['shipping'];
    final payment = json['payment'];
    final createdAt = DateTime.tryParse(_text(json, 'createdAt'));
    final updatedAt = json['updatedAt'] == null
        ? null
        : DateTime.tryParse(_text(json, 'updatedAt'));
    final history = json['statusHistory'];
    final actions = json['actions'];
    final returnRequest = json['returnRequest'];
    final revision = json['revision'] ?? 0;
    if (revision is! int ||
        revision < 0 ||
        (actions != null &&
            (actions is! Map ||
                actions['canCancel'] is! bool ||
                actions['canReturn'] is! bool)) ||
        (returnRequest != null && returnRequest is! Map<String, dynamic>)) {
      throw const FormatException('Invalid order actions.');
    }
    if ((json['updatedAt'] != null && updatedAt == null) ||
        (history != null &&
            (history is! List ||
                history.length > 1000 ||
                history.any((row) => row is! Map<String, dynamic>)))) {
      throw const FormatException('Invalid order updates.');
    }
    final status = _text(json, 'status');
    final paymentStatus = _text(json, 'paymentStatus');
    final currency = _text(json, 'currency');
    if (rows is! List ||
        rows.isEmpty ||
        rows.length > 50 ||
        rows.any((row) => row is! Map<String, dynamic>) ||
        address is! Map<String, dynamic> ||
        createdAt == null ||
        currency != 'PHP' ||
        !const [
          'pending',
          'confirmed',
          'processing',
          'shipped',
          'completed',
          'cancelled',
          'delayed',
        ].contains(status) ||
        !const ['unpaid', 'paid', 'simulated'].contains(paymentStatus) ||
        (payment != null && payment is! Map<String, dynamic>)) {
      throw const FormatException('Invalid order receipt.');
    }
    final shipping = <String, String>{};
    for (final key in ['name', 'email', 'phone', 'address']) {
      shipping[key] = _text(address, key);
    }
    for (final key in ['notes', 'city', 'province', 'postalCode', 'country']) {
      if (address[key] != null) {
        shipping[key] = _text(address, key, optional: true);
      }
    }
    if (payment != null) {
      for (final key in ['method', 'brand', 'last4', 'mode', 'reference']) {
        _text(payment as Map<String, dynamic>, key);
      }
    }
    return StoreOrder(
      id: _text(json, 'id'),
      orderNumber: _text(json, 'orderNumber'),
      status: status,
      paymentStatus: paymentStatus,
      currency: currency,
      items: rows
          .map((row) => OrderItem.fromJson(row as Map<String, dynamic>))
          .toList(),
      shipping: shipping,
      subtotal: _money(json, 'subtotal'),
      shippingFee: _money(json, 'shippingFee'),
      tax: _money(json, 'tax'),
      total: _money(json, 'total'),
      createdAt: createdAt,
      updatedAt: updatedAt,
      revision: revision,
      canCancel: actions is Map && actions['canCancel'] == true,
      canReturn: actions is Map && actions['canReturn'] == true,
      returnRequest: returnRequest == null
          ? null
          : ReturnRequest.fromJson(returnRequest as Map<String, dynamic>),
      statusHistory: (history as List?)
          ?.map((row) => OrderStatusEvent.fromJson(row as Map<String, dynamic>))
          .toList(),
      payment: payment as Map<String, dynamic>?,
    );
  }
}
