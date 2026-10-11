const returnLabels = {
  'requested': 'Return requested',
  'approved': 'Return approved',
  'rejected': 'Return declined',
  'received': 'Return inspected',
  'closed': 'Refund recorded',
};

class ReturnEvent {
  const ReturnEvent(this.state, this.at, this.reason);
  final String state, reason;
  final DateTime at;
  String get label => returnLabels[state]!;
}

class OrderRefund {
  const OrderRefund(this.amount, this.reference, this.at);
  final double amount;
  final String reference;
  final DateTime at;
}

class ReturnInspection {
  const ReturnInspection(this.productId, this.restock, this.reason);
  final String productId, reason;
  final bool restock;
}

class ReturnRequest {
  const ReturnRequest({
    required this.id,
    required this.state,
    required this.reason,
    required this.history,
    this.inspection = const [],
    this.refund,
  });
  final String id, state, reason;
  final List<ReturnEvent> history;
  final List<ReturnInspection> inspection;
  final OrderRefund? refund;
  String get label => returnLabels[state]!;
  factory ReturnRequest.fromJson(Map<String, dynamic> json) {
    String text(Map value, String key) {
      final result = value[key];
      if (result is! String || result.isEmpty) {
        throw const FormatException('Invalid return response.');
      }
      return result;
    }

    DateTime date(Map value, String key) {
      final result = DateTime.tryParse(text(value, key));
      if (result == null) throw const FormatException('Invalid return date.');
      return result;
    }

    String state(Map value) {
      final result = text(value, 'state');
      if (!returnLabels.containsKey(result)) {
        throw const FormatException('Invalid return status.');
      }
      return result;
    }

    final rows = json['history'];
    if (rows is! List || rows.length > 100 || rows.any((row) => row is! Map)) {
      throw const FormatException('Invalid return history.');
    }
    final refund = json['refund'];
    final inspection = json['inspection'] ?? const [];
    if (inspection is! List || inspection.length > 100) {
      throw const FormatException('Invalid return inspection.');
    }
    final inspected = inspection
        .map((row) {
          if (row is! Map || row['restock'] is! bool) {
            throw const FormatException('Invalid return inspection.');
          }
          return ReturnInspection(
            text(row, 'productId'),
            row['restock'] as bool,
            text(row, 'reason'),
          );
        })
        .toList(growable: false);
    OrderRefund? parsed;
    if (refund != null) {
      if (refund is! Map ||
          refund['mode'] != 'simulated' ||
          refund['amount'] is! num ||
          !(refund['amount'] as num).isFinite ||
          refund['amount'] < 0) {
        throw const FormatException('Invalid refund response.');
      }
      parsed = OrderRefund(
        (refund['amount'] as num).toDouble(),
        text(refund, 'reference'),
        date(refund, 'at'),
      );
    }
    return ReturnRequest(
      id: text(json, 'id'),
      state: state(json),
      reason: text(json, 'reason'),
      history: List.unmodifiable(
        rows.map(
          (row) => ReturnEvent(
            state(row as Map),
            date(row, 'at'),
            row['reason'] is String ? row['reason'] as String : '',
          ),
        ),
      ),
      refund: parsed,
      inspection: List.unmodifiable(inspected),
    );
  }
}
