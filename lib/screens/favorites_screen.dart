import 'package:flutter/material.dart';
import '../models/product.dart';
import '../widgets/favorites_scope.dart';
import '../widgets/store_widgets.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key, required this.onProduct});
  final ValueChanged<Product> onProduct;
  @override
  Widget build(BuildContext context) {
    final state = FavoritesScope.maybeOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: state == null
          ? const Center(child: Text('Sign in to view favorites.'))
          : RefreshIndicator(
              onRefresh: state.load,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (state.loading) const LinearProgressIndicator(),
                  if (state.error != null) ...[
                    Text(state.error!),
                    TextButton(
                      onPressed: state.load,
                      child: const Text('Try again'),
                    ),
                  ],
                  if (!state.loading && state.entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'No favorites yet. Save a card using its heart.',
                      ),
                    ),
                  for (final entry in state.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: entry.available && entry.product != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  height: 420,
                                  child: ProductTile(
                                    product: entry.product!,
                                    onTap: () => onProduct(entry.product!),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(entry.product?.name ?? 'Unavailable card'),
                                const SizedBox(height: 12),
                                const Text(
                                  'This card is currently unavailable.',
                                ),
                                TextButton(
                                  onPressed:
                                      state.pending.contains(entry.productId)
                                      ? null
                                      : () => state.toggle(entry.productId),
                                  child: const Text('Remove favorite'),
                                ),
                              ],
                            ),
                    ),
                ],
              ),
            ),
    );
  }
}
