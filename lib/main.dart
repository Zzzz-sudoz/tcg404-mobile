import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'widgets/store_widgets.dart';
import 'models/product.dart';
import 'services/catalog_api.dart';
import 'screens/home_screen.dart';

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
  void _shop(String game) {
    final products = _api.list({'game': game, 'limit': '12'});
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Cards')),
          body: FutureBuilder<ProductPage>(
            future: products,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return StoreMessage(
                  title: 'Cards unavailable',
                  message: snapshot.error.toString(),
                  action: 'Back',
                  onAction: () => Navigator.of(context).pop(),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView(
                children: [
                  for (final product in snapshot.data!.items)
                    ListTile(
                      title: Text(product.name),
                      subtitle: Text(money(product.price)),
                      onTap: () => _product(product),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: StoreBackdrop(
      child: SafeArea(
        child: HomeScreen(api: _api, onProduct: _product, onShop: _shop),
      ),
    ),
  );
}
