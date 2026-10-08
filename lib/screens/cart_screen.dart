import 'package:flutter/material.dart';
import '../state/cart_state.dart';
import '../theme/app_theme.dart';
import '../widgets/store_widgets.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({
    super.key,
    required this.cart,
    required this.onShop,
    required this.onCheckout,
  });
  final CartState cart;
  final VoidCallback onShop, onCheckout;
  Future<void> _quantity(BuildContext context, String id, int quantity) async {
    final error = await cart.setQuantity(id, quantity);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: cart,
    builder: (context, child) {
      if (!cart.ready) return const Center(child: CircularProgressIndicator());
      if (cart.restoreFailed) {
        return SingleChildScrollView(
          child: Column(
            children: [
              StoreMessage(
                title: 'Saved cart needs attention',
                message: cart.error ?? 'Your saved cart could not be restored.',
                action: 'Retry restore',
                onAction: cart.restore,
              ),
              TextButton(
                onPressed: () async {
                  final reset = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Reset saved cart?'),
                      content: const Text(
                        'This removes the unreadable cart saved on this device.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Keep saved cart'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Reset cart'),
                        ),
                      ],
                    ),
                  );
                  if (reset == true) await cart.resetSavedCart();
                },
                child: const Text('Reset saved cart'),
              ),
            ],
          ),
        );
      }
      if (cart.lines.isEmpty) {
        return StoreMessage(
          title: 'ROOM FOR A GREAT FIND.',
          message: cart.error ?? 'Your cart is waiting for its first single.',
          icon: Icons.shopping_bag_outlined,
          action: 'Explore cards',
          onAction: onShop,
        );
      }
      return Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: cart.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'YOUR CART.',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pull to refresh availability and prices.',
                    style: TextStyle(color: TcgColors.muted),
                  ),
                  if (cart.error != null)
                    StoreMessage(
                      title: 'Cart needs attention',
                      message: cart.error!,
                      action: 'Retry',
                      onAction: cart.refresh,
                    ),
                  if (cart.notice != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        cart.notice!,
                        style: const TextStyle(color: TcgColors.yellow),
                      ),
                    ),
                  const SizedBox(height: 20),
                  for (final line in cart.lines)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: TcgColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: TcgColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 72,
                                height: 100,
                                child: line.product != null
                                    ? CardArtwork(product: line.product!)
                                    : const Icon(Icons.style_outlined),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      line.product?.name ?? 'Unavailable card',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (line.product != null)
                                      Text(
                                        line.product!.condition,
                                        style: const TextStyle(
                                          color: TcgColors.muted,
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    Text(
                                      money(line.totalCents / 100),
                                      style: const TextStyle(
                                        color: TcgColors.yellow,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (line.reason != null)
                            Text(
                              line.reason!,
                              style: const TextStyle(color: TcgColors.red),
                            ),
                          if (line.priceChanged)
                            const Text(
                              'Price updated to the current listing.',
                              style: TextStyle(color: TcgColors.yellow),
                            ),
                          if (line.stockChanged)
                            const Text(
                              'Availability has changed. Check your quantity.',
                              style: TextStyle(color: TcgColors.yellow),
                            ),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 16,
                            children: [
                              QuantityControl(
                                value: line.quantity,
                                maximum: line.product?.stock ?? 0,
                                enabled: !cart.busy && line.product != null,
                                onChanged: (value) =>
                                    _quantity(context, line.id, value),
                              ),
                              IconButton.filledTonal(
                                tooltip:
                                    'Remove ${line.product?.name ?? 'card'} from cart',
                                style: IconButton.styleFrom(
                                  foregroundColor: TcgColors.red,
                                  backgroundColor: TcgColors.red.withValues(
                                    alpha: .12,
                                  ),
                                ),
                                onPressed: cart.busy
                                    ? null
                                    : () => cart.remove(line.id),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: TcgColors.surface,
              border: Border(top: BorderSide(color: TcgColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 16,
                  children: [
                    const Text('Subtotal'),
                    Text(
                      money(cart.subtotalCents / 100),
                      style: const TextStyle(
                        color: TcgColors.yellow,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: cart.valid && !cart.busy ? onCheckout : null,
                  child: const Text('Continue to checkout'),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}
