import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/catalog_api.dart';
import '../theme/app_theme.dart';
import '../widgets/store_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.api,
    required this.onProduct,
    required this.onShop,
  });
  final CatalogApi api;
  final ValueChanged<Product> onProduct;
  final ValueChanged<String> onShop;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<ProductPage>> _data;
  List<ProductPage>? _lastData;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _data = Future.wait([
      widget.api.list({'featured': 'true', 'limit': '8'}),
      widget.api.list({'new': 'true', 'limit': '6'}),
    ]);
  }

  Future<void> _refresh() async {
    setState(_load);
    try {
      await _data;
    } on CatalogException {
      return;
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'TCG404.',
          style: TextStyle(
            fontFamily: 'Barlow',
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: TcgColors.yellow,
          ),
        ),
        const Text(
          'Collect. Trade. Discover.',
          style: TextStyle(color: TcgColors.muted),
        ),
        const SizedBox(height: 24),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: TcgColors.border),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/collector-backdrop.png',
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        TcgColors.bg.withValues(alpha: .8),
                        TcgColors.bg.withValues(alpha: .95),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 88, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'THE COLLECTOR’S SHELF',
                      style: TextStyle(
                        color: TcgColors.yellow,
                        letterSpacing: 2,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'YOUR NEXT\nGREAT FIND.',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Find the missing piece of your collection.',
                      style: TextStyle(color: TcgColors.muted),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => widget.onShop(''),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Explore cards'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const SectionTitle(title: 'PICK YOUR WORLD.'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final game in const [
              ('pokemon', 'Pokémon'),
              ('one-piece', 'One Piece'),
              ('magic', 'Magic'),
            ])
              ActionChip(
                avatar: const Icon(Icons.style_outlined, size: 18),
                label: Text(game.$2),
                onPressed: () => widget.onShop(game.$1),
              ),
          ],
        ),
        const SizedBox(height: 24),
        FutureBuilder<List<ProductPage>>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.hasError && _lastData == null) {
              return StoreMessage(
                title: 'Shelf unavailable',
                message: snapshot.error is CatalogException
                    ? (snapshot.error as CatalogException).message
                    : 'Check your connection and try again.',
                action: 'Retry',
                onAction: () => setState(_load),
              );
            }
            if (!snapshot.hasData && _lastData == null) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Loading your shelf',
                  ),
                ),
              );
            }
            if (snapshot.hasData) _lastData = snapshot.data;
            final featured = _lastData![0].items;
            final arrivals = _lastData![1].items;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (snapshot.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator(
                    semanticsLabel: 'Refreshing your shelf',
                  ),
                if (snapshot.hasError)
                  StoreMessage(
                    title: 'Shelf update unavailable',
                    message:
                        'Your last loaded cards are shown. Check your connection and retry.',
                    action: 'Retry',
                    onAction: () => setState(_load),
                  ),
                SectionTitle(
                  title: 'THE CHASE LIST.',
                  action: 'Shop all',
                  onAction: () => widget.onShop(''),
                ),
                const SizedBox(height: 16),
                if (featured.isEmpty)
                  const StoreMessage(
                    title: 'A new shelf awaits',
                    message: 'Browse the catalog to discover available cards.',
                  ),
                if (featured.isNotEmpty)
                  SizedBox(
                    height:
                        360 +
                        (MediaQuery.textScalerOf(context).scale(100) - 100) *
                            1.8,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: featured.length,
                      separatorBuilder: (_, index) => const SizedBox(width: 12),
                      itemBuilder: (_, index) => SizedBox(
                        width: 190,
                        child: ProductTile(
                          product: featured[index],
                          onTap: () => widget.onProduct(featured[index]),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 28),
                const SectionTitle(title: 'JUST LANDED.'),
                const SizedBox(height: 12),
                for (final product in arrivals)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: TcgColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => widget.onProduct(product),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 64,
                                height: 88,
                                child: CardArtwork(product: product),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      product.gameName,
                                      style: const TextStyle(
                                        color: TcgColors.muted,
                                      ),
                                    ),
                                    Text(
                                      money(product.price),
                                      style: const TextStyle(
                                        color: TcgColors.yellow,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: TcgColors.lavender.withValues(alpha: .4)),
            gradient: LinearGradient(
              colors: [
                TcgColors.lavender.withValues(alpha: .16),
                TcgColors.surface.withValues(alpha: .7),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A DECK TO PLAY.\nA COLLECTION TO KEEP.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'Check the set, card number and condition. Make room for a card that means something to you.',
                style: TextStyle(color: TcgColors.muted),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => widget.onShop(''),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Find your single'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    ),
  );
}
