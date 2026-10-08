import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/cart_screen.dart';
import 'screens/home_screen.dart';
import 'screens/product_screen.dart';
import 'screens/shop_screen.dart';
import 'models/product.dart';
import 'services/catalog_api.dart';
import 'state/cart_state.dart';
import 'theme/app_theme.dart';
import 'widgets/store_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = CatalogApi();
  final cart = CartState(
    api: api,
    preferences: await SharedPreferences.getInstance(),
  );
  runApp(Tcg404App(api: api, cart: cart));
  await cart.restore();
}

class Tcg404App extends StatelessWidget {
  const Tcg404App({super.key, required this.api, required this.cart});
  final CatalogApi api;
  final CartState cart;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TCG404',
    debugShowCheckedModeBanner: false,
    theme: storeTheme(),
    home: StoreShell(api: api, cart: cart),
  );
}

class StoreShell extends StatefulWidget {
  const StoreShell({super.key, required this.api, required this.cart});
  final CatalogApi api;
  final CartState cart;
  @override
  State<StoreShell> createState() => _StoreShellState();
}

class _StoreShellState extends State<StoreShell> {
  int _tab = 0;
  String _game = '';
  int _shopRevision = 0;
  void _shop(String game) => setState(() {
    _game = game;
    _shopRevision++;
    _tab = 1;
  });
  void _product(Product product) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: RouteSettings(name: '/product/${product.id}'),
      builder: (_) => ProductScreen(
        api: widget.api,
        cart: widget.cart,
        id: product.id,
        onCart: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
          setState(() => _tab = 2);
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: StoreBackdrop(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: IndexedStack(
              index: _tab,
              children: [
                HomeScreen(api: widget.api, onProduct: _product, onShop: _shop),
                ShopScreen(
                  key: ValueKey(_shopRevision),
                  api: widget.api,
                  onProduct: _product,
                  initialGame: _game,
                ),
                CartScreen(cart: widget.cart, onShop: () => _shop('')),
              ],
            ),
          ),
        ),
      ),
    ),
    bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
        ? null
        : ListenableBuilder(
            listenable: widget.cart,
            builder: (context, child) => NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (value) {
                setState(() => _tab = value);
                if (value == 2) widget.cart.refresh();
              },
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.style_outlined),
                  selectedIcon: Icon(Icons.style),
                  label: 'Shop',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: widget.cart.count > 0,
                    label: Text('${widget.cart.count}'),
                    child: Semantics(
                      label:
                          '${widget.cart.count} ${widget.cart.count == 1 ? 'card' : 'cards'} in cart',
                      child: const Icon(Icons.shopping_bag_outlined),
                    ),
                  ),
                  label: 'Cart',
                ),
              ],
            ),
          ),
  );
}
