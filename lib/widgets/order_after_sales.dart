import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/commerce_api.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import 'store_widgets.dart';

class OrderAfterSales extends StatefulWidget {
  const OrderAfterSales({
    super.key,
    required this.order,
    required this.api,
    required this.auth,
    required this.refresh,
  });
  final StoreOrder order;
  final CommerceApi api;
  final AuthState auth;
  final Future<void> Function() refresh;
  @override
  State<OrderAfterSales> createState() => _OrderAfterSalesState();
}

class _OrderAfterSalesState extends State<OrderAfterSales> {
  bool _busy = false;
  Future<void> _act(bool cancel) async {
    if (_busy) return;
    final owner = widget.auth.user?.id;
    var reason = '';
    String? error;
    bool saving = false;
    final form = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: Text(cancel ? 'Cancel this order?' : 'Return this order'),
            content: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      cancel
                          ? 'This cancels the order and returns its reserved stock.'
                          : 'Return all items in this order. Your refund is reviewed after the items are received and inspected.',
                    ),
                    if (!cancel) ...[
                      const SizedBox(height: 24),
                      TextFormField(
                        initialValue: reason,
                        onChanged: (value) => reason = value,
                        enabled: !saving,
                        maxLength: 500,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Reason for return',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter a reason.'
                            : null,
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        error!,
                        style: TextStyle(color: TcgColors.of(context).red),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: Text(cancel ? 'Keep order' : 'Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        if (owner == null ||
                            owner != widget.auth.user?.id ||
                            widget.auth.user?.role == 'admin') {
                          Navigator.pop(dialogContext);
                          return;
                        }
                        setDialog(() => saving = true);
                        setState(() => _busy = true);
                        try {
                          await widget.api.request(
                            'POST',
                            'orders/${widget.order.id}/${cancel ? 'cancel' : 'returns'}',
                            body: {
                              'revision': widget.order.revision,
                              if (!cancel) 'reason': reason.trim(),
                            },
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          if (mounted && widget.auth.user?.id == owner) {
                            await widget.refresh();
                          }
                        } on ApiFailure catch (failure) {
                          if (dialogContext.mounted) {
                            setDialog(() => error = failure.message);
                          }
                        } finally {
                          if (dialogContext.mounted) {
                            setDialog(() => saving = false);
                          }
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                child: Text(
                  saving
                      ? 'Saving...'
                      : cancel
                      ? 'Cancel order'
                      : 'Submit request',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.auth.user?.role == 'admin') return const SizedBox.shrink();
    final record = widget.order.returnRequest;
    if (!widget.order.canCancel && !widget.order.canReturn && record == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.order.canCancel)
            OutlinedButton(
              onPressed: _busy ? null : () => _act(true),
              child: const Text('Cancel order'),
            ),
          if (widget.order.canReturn)
            FilledButton(
              onPressed: _busy ? null : () => _act(false),
              child: const Text('Request return & refund'),
            ),
          if (record != null) ...[
            Text(record.label, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text(record.reason),
            const SizedBox(height: 20),
            for (final event in record.history)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      event.at.toLocal().toString(),
                      style: TextStyle(color: TcgColors.of(context).muted),
                    ),
                    if (event.reason.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(event.reason),
                    ],
                  ],
                ),
              ),
            for (final inspected in record.inspection) ...[
              Text(
                inspected.restock
                    ? 'Returned to stock'
                    : 'Not returned to stock',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(inspected.reason),
              const SizedBox(height: 20),
            ],
            if (record.refund != null) ...[
              Text(
                'Refund recorded: ${money(record.refund!.amount)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(record.refund!.at.toLocal().toString()),
              const SizedBox(height: 8),
              SelectableText(record.refund!.reference),
            ],
          ],
        ],
      ),
    );
  }
}
