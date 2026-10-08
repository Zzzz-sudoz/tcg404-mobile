int priceToCents(double price) {
  if (!price.isFinite || price < 0) {
    throw const FormatException('Invalid product price.');
  }
  final parts = price.toString().toLowerCase().split('e');
  final decimal = parts.first.split('.');
  final fraction = decimal.length == 2 ? decimal[1] : '';
  final digits = BigInt.parse(decimal.first + fraction);
  final scale =
      fraction.length - (parts.length == 2 ? int.parse(parts[1]) : 0) - 2;
  final divisor = BigInt.from(10).pow(scale.abs());
  final cents = scale <= 0
      ? digits * divisor
      : (digits + divisor ~/ BigInt.two) ~/ divisor;
  if (cents > BigInt.from(9007199254740991)) {
    throw const FormatException('Invalid product price.');
  }
  return cents.toInt();
}

class Product {
  Product({
    required this.id,
    required this.name,
    required this.slug,
    required this.game,
    required this.setName,
    required this.rarity,
    required this.condition,
    required this.stock,
    required this.price,
    this.imageUrl = '',
    this.description = '',
    this.cardNumber = '',
    this.language = 'English',
    this.finish = '',
    this.source,
    Map<String, dynamic>? marketReference,
    this.isActive = true,
  }) : marketReference = marketReference == null
           ? null
           : Map<String, dynamic>.unmodifiable(marketReference);

  final String id;
  final String name;
  final String slug;
  final String game;
  final String setName;
  final String rarity;
  final String condition;
  final String imageUrl;
  final String description;
  final String cardNumber;
  final String language;
  final String finish;
  final String? source;
  final int stock;
  final double price;
  final Map<String, dynamic>? marketReference;
  final bool isActive;

  String get gameName => switch (game) {
    'pokemon' => 'Pokémon',
    'one-piece' => 'One Piece',
    'magic' => 'Magic: The Gathering',
    _ => game,
  };

  factory Product.fromJson(Map<String, dynamic> json) {
    String text(String key, {String? fallback}) {
      final value = json[key] ?? fallback;
      if (value is! String || (fallback == null && value.trim().isEmpty)) {
        throw const FormatException('Invalid product information.');
      }
      return value;
    }

    final price = json['price'];
    final stock = json['stock'];
    final active = json['isActive'] ?? true;
    final source = json['source'];
    final reference = json['marketReference'];
    if (price is! num ||
        stock is! int ||
        stock < 0 ||
        stock > 9007199254740991 ||
        active is! bool ||
        (source != null && source is! String) ||
        (reference != null && reference is! Map<String, dynamic>)) {
      throw const FormatException('Invalid product inventory.');
    }
    priceToCents(price.toDouble());
    final game = text('game');
    if (!const ['pokemon', 'one-piece', 'magic'].contains(game)) {
      throw const FormatException('Invalid product game.');
    }
    return Product(
      id: text('id'),
      name: text('name'),
      slug: text('slug'),
      game: game,
      setName: text('setName'),
      rarity: text('rarity'),
      condition: text('condition'),
      imageUrl: text('imageUrl', fallback: ''),
      description: text('description', fallback: ''),
      cardNumber: text('cardNumber', fallback: ''),
      language: text('language', fallback: 'English'),
      finish: text('finish', fallback: ''),
      source: source as String?,
      stock: stock,
      price: price.toDouble(),
      isActive: active,
      marketReference: reference as Map<String, dynamic>?,
    );
  }
}

class ProductPage {
  ProductPage({
    required List<Product> items,
    required this.total,
    required this.page,
    required this.totalPages,
    required Map<String, List<String>> facets,
  }) : items = List.unmodifiable(items),
       facets = Map.unmodifiable(
         facets.map(
           (key, value) => MapEntry(key, List<String>.unmodifiable(value)),
         ),
       );

  final List<Product> items;
  final int total;
  final int page;
  final int totalPages;
  final Map<String, List<String>> facets;
}
