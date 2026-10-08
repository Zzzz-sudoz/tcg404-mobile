import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'widgets/store_widgets.dart';
import 'models/product.dart';
import 'services/catalog_api.dart';
import 'screens/home_screen.dart';
import 'screens/shop_screen.dart';

void main() => runApp(
  MaterialApp(
    title: 'TCG404',
    debugShowCheckedModeBanner: false,
    theme: storeTheme(),
    home: const MobileStore(),
  ),
);

class MobileStore extends StatefulWidget {
  const MobileStore({super.key});
  @override
  State<MobileStore> createState() => _MobileStoreState();
}

class _MobileStoreState extends State<MobileStore> {
  final _api = CatalogApi();
  void _product(Product product) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: .85,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(child: CardArtwork(product: product)),
            Text(
              product.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text('${product.gameName} · ${product.setName}'),
            Text(money(product.price)),
          ],
        ),
      ),
    ),
  );
  int _tab = 0;
  String _game = '';
  int _revision = 0;
  void _shop(String game) => setState(() {
    _game = game;
    _revision++;
    _tab = 1;
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    body: StoreBackdrop(
      child: SafeArea(
        child: IndexedStack(
          index: _tab,
          children: [
            HomeScreen(api: _api, onProduct: _product, onShop: _shop),
            ShopScreen(
              key: ValueKey(_revision),
              api: _api,
              onProduct: _product,
              initialGame: _game,
            ),
          ],
        ),
      ),
    ),
    bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
        ? null
        : NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (value) => setState(() => _tab = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.style_outlined),
                label: 'Shop',
              ),
            ],
          ),
  );
}
