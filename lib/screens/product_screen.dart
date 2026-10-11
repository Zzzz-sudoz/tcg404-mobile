import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/catalog_api.dart';
import '../state/cart_state.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/store_widgets.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({
    super.key,
    required this.api,
    required this.cart,
    required this.id,
    required this.onCart,
    this.auth,
  });
  final CatalogApi api;
  final CartState cart;
  final String id;
  final VoidCallback onCart;
  final AuthState? auth;
  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  late Future<Product> _product;
  int _quantity = 1;
  bool _adding = false;
  @override
  void initState() {
    super.initState();
    _product = widget.api.product(widget.id);
  }

  Future<void> _add(Product product, int quantity) async {
    setState(() => _adding = true);
    final error = await widget.cart.add(product, quantity);
    if (!mounted) return;
    setState(() => _adding = false);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final checkCart = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Item added to cart', textAlign: TextAlign.center),
        titlePadding: const EdgeInsets.all(24),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Check cart'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continue shopping'),
            ),
          ],
        ),
      ),
    );
    if (checkCart == true && mounted) widget.onCart();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.auth, widget.cart]),
    builder: (context, child) => Scaffold(
      appBar: AppBar(title: const Text('The single')),
      body: StoreBackdrop(
        child: SafeArea(
          child: FutureBuilder<Product>(
            future: _product,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                final failure = snapshot.error;
                final missing =
                    failure is CatalogException && failure.statusCode == 404;
                return StoreMessage(
                  title: 'Card unavailable',
                  message: failure is CatalogException
                      ? failure.message
                      : 'This card could not be loaded. Try again.',
                  action: missing ? 'Back to shop' : 'Retry',
                  onAction: missing
                      ? () => Navigator.maybePop(context)
                      : () => setState(
                          () => _product = widget.api.product(widget.id),
                        ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Loading card',
                  ),
                );
              }
              final line = widget.cart.lines
                  .where((line) => line.id == widget.id)
                  .firstOrNull;
              final product = line?.product ?? snapshot.data!;
              final inCart = line?.quantity ?? 0;
              final remaining = (product.stock.clamp(0, 10) - inCart).clamp(
                0,
                10,
              );
              final quantity = _quantity.clamp(1, remaining.clamp(1, 10));
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            Container(
                              height: 350,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: TcgColors.border),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    TcgColors.lavender.withValues(alpha: .17),
                                    TcgColors.surface,
                                  ],
                                ),
                              ),
                              child: CardArtwork(product: product),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              product.gameName.toUpperCase(),
                              style: const TextStyle(
                                color: TcgColors.lavender,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              product.name,
                              style: Theme.of(context).textTheme.headlineLarge,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              money(product.price),
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(color: TcgColors.yellow),
                            ),
                            Text(
                              product.stock > 0
                                  ? '${product.stock} available'
                                  : 'Out of stock',
                              style: const TextStyle(color: TcgColors.muted),
                            ),
                            const SizedBox(height: 24),
                            for (final row in [
                              ('Set', product.setName),
                              ('Card number', product.cardNumber),
                              ('Rarity', product.rarity),
                              ('Condition', product.condition),
                              ('Language', product.language),
                              ('Finish', product.finish),
                            ])
                              if (row.$2.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Wrap(
                                    spacing: 16,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        '${row.$1}:',
                                        style: const TextStyle(
                                          color: TcgColors.muted,
                                        ),
                                      ),
                                      Text(row.$2),
                                    ],
                                  ),
                                ),
                            if (product.description.isNotEmpty &&
                                !RegExp(
                                  r'demonstration|demo values|no payment|no physical|inventory is verified',
                                  caseSensitive: false,
                                ).hasMatch(product.description))
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                child: Text(product.description),
                              ),
                            if (product.marketReference case final reference?)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  'Market reference: ${reference['currency'] ?? ''} ${reference['price'] ?? '—'} · ${reference['source'] ?? product.source ?? ''}',
                                  style: const TextStyle(
                                    color: TcgColors.muted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (widget.auth?.user?.role != 'admin')
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: TcgColors.surface,
                            border: Border(
                              top: BorderSide(color: TcgColors.border),
                            ),
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 16,
                            runSpacing: 8,
                            children: [
                              QuantityControl(
                                value: quantity,
                                maximum: remaining,
                                enabled: !_adding && remaining > 0,
                                onChanged: (value) =>
                                    setState(() => _quantity = value),
                              ),
                              FilledButton.icon(
                                onPressed: !_adding && remaining > 0
                                    ? () => _add(product, quantity)
                                    : null,
                                icon: const Icon(Icons.add_shopping_cart),
                                label: Text(
                                  _adding
                                      ? 'Adding…'
                                      : product.stock == 0
                                      ? 'Out of stock'
                                      : remaining > 0
                                      ? 'Add to cart'
                                      : 'In your cart',
                                ),
                              ),
                              if (inCart > 0) ...[
                                Text(
                                  '$inCart in your cart.${remaining == 0
                                      ? product.stock <= inCart
                                            ? ' All available stock is already in your cart.'
                                            : ' The limit is 10 per card.'
                                      : ''}',
                                ),
                                TextButton(
                                  onPressed: widget.onCart,
                                  child: const Text('Check cart'),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}
