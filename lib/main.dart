import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/cart_screen.dart';
import 'screens/home_screen.dart';
import 'screens/product_screen.dart';
import 'screens/shop_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/account_screen.dart';
import 'screens/orders_screen.dart';
import 'services/commerce_api.dart';
import 'state/auth_state.dart';
import 'models/product.dart';
import 'services/catalog_api.dart';
import 'state/cart_state.dart';
import 'theme/app_theme.dart';
import 'widgets/store_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = CatalogApi();
  final commerce = CommerceApi(baseUrl: api.baseUrl);
  final auth = AuthState(api: commerce);
  final cart = CartState(
    api: api,
    preferences: await SharedPreferences.getInstance(),
  );
  runApp(Tcg404App(api: api, cart: cart, commerce: commerce, auth: auth));
  await Future.wait([cart.restore(), auth.restore()]);
}

class Tcg404App extends StatelessWidget {
  const Tcg404App({
    super.key,
    required this.api,
    required this.cart,
    required this.commerce,
    required this.auth,
  });
  final CatalogApi api;
  final CartState cart;
  final CommerceApi commerce;
  final AuthState auth;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TCG404',
    debugShowCheckedModeBanner: false,
    theme: storeTheme(),
    home: StoreShell(api: api, cart: cart, commerce: commerce, auth: auth),
  );
}

class StoreShell extends StatefulWidget {
  const StoreShell({
    super.key,
    required this.api,
    required this.cart,
    required this.commerce,
    required this.auth,
  });
  final CatalogApi api;
  final CartState cart;
  final CommerceApi commerce;
  final AuthState auth;
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
  Future<bool> _signIn({bool register = false}) async =>
      await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          settings: RouteSettings(name: register ? '/register' : '/login'),
          builder: (_) => AuthScreen(auth: widget.auth, register: register),
        ),
      ) ??
      false;
  void _orders() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/orders'),
      builder: (_) => OrdersScreen(
        api: widget.commerce,
        auth: widget.auth,
        onShop: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
          _shop('');
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
                AccountScreen(
                  auth: widget.auth,
                  onSignIn: _signIn,
                  onRegister: () => _signIn(register: true),
                  onOrders: _orders,
                ),
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
                const NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  label: 'Account',
                ),
              ],
            ),
          ),
  );
}
