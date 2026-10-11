import 'package:flutter/material.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';
import 'favorites_scope.dart';

String money(double value) =>
    '₱${(priceToCents(value) / 100).toStringAsFixed(2)}';

class StoreBackdrop extends StatelessWidget {
  const StoreBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: Opacity(
          opacity: .12,
          child: Image.asset(
            'assets/collector-backdrop.png',
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
        ),
      ),
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                TcgColors.bg.withValues(alpha: .2),
                TcgColors.bg.withValues(alpha: .94),
              ],
            ),
          ),
        ),
      ),
      child,
    ],
  );
}

class CardArtwork extends StatelessWidget {
  const CardArtwork({super.key, required this.product});
  final Product product;
  @override
  Widget build(BuildContext context) {
    Widget fallback(BuildContext context, Object error, StackTrace? stack) =>
        Semantics(
          label: 'Artwork unavailable for ${product.name}',
          image: true,
          child: const Center(
            child: Icon(Icons.style_outlined, size: 48, color: TcgColors.muted),
          ),
        );
    final path = product.imageUrl;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: path.startsWith('/cards/')
          ? Image.asset(
              'assets/cards/${path.split('/').last}',
              fit: BoxFit.contain,
              errorBuilder: fallback,
              semanticLabel: '${product.name} card artwork',
            )
          : path.startsWith('https://')
          ? Image.network(
              path,
              fit: BoxFit.contain,
              errorBuilder: fallback,
              semanticLabel: '${product.name} card artwork',
              webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
            )
          : fallback(context, StateError('Missing artwork'), null),
    );
  }
}

class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.product, required this.onTap});
  final Product product;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: TcgColors.surface,
    borderRadius: BorderRadius.circular(20),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: TcgColors.raised,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CardArtwork(product: product),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: FavoriteButton(product: product),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              product.gameName,
              style: const TextStyle(color: TcgColors.lavender, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              product.setName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: TcgColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              '${product.rarity} · ${product.condition}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: TcgColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              money(product.price),
              style: const TextStyle(
                color: TcgColors.yellow,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              product.stock > 0 ? '${product.stock} in stock' : 'Out of stock',
              style: const TextStyle(color: TcgColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 16,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineMedium),
      if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
    ],
  );
}

class StoreMessage extends StatelessWidget {
  const StoreMessage({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.style_outlined,
    this.action,
    this.onAction,
  });
  final String title, message;
  final IconData icon;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: TcgColors.lavender),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: TcgColors.muted),
              ),
              if (action != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: FilledButton(
                    onPressed: onAction,
                    child: Text(action!),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class QuantityControl extends StatelessWidget {
  const QuantityControl({
    super.key,
    required this.value,
    required this.maximum,
    required this.onChanged,
    this.enabled = true,
  });
  final int value, maximum;
  final bool enabled;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'Decrease quantity',
        onPressed: enabled && value > 1 && maximum > 0
            ? () => onChanged(value > maximum ? maximum : value - 1)
            : null,
        icon: const Icon(Icons.remove),
      ),
      Semantics(
        label: 'Quantity $value',
        excludeSemantics: true,
        liveRegion: true,
        child: Text('$value'),
      ),
      IconButton(
        tooltip: 'Increase quantity',
        onPressed: enabled && value < maximum
            ? () => onChanged(value + 1)
            : null,
        icon: const Icon(Icons.add),
      ),
    ],
  );
}
