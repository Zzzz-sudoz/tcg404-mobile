import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/catalog_api.dart';
import '../theme/app_theme.dart';
import '../widgets/store_widgets.dart';
import 'filter_sheet.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({
    super.key,
    required this.api,
    required this.onProduct,
    this.initialGame = '',
    this.initialSearch = '',
  });

  final CatalogApi api;
  final void Function(Product) onProduct;
  final String initialGame;
  final String initialSearch;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late final TextEditingController _search;
  final _scroll = ScrollController();
  final _searchKey = GlobalKey();
  final _searchFocus = FocusNode();
  double _keyboard = 0;
  Timer? _debounce;
  Map<String, String> _filters = {};
  List<Product> _items = [];
  int _request = 0;
  int _page = 0;
  int _total = 0;
  int _totalPages = 0;
  bool _loading = true;
  bool _more = false;
  bool _retryMore = false;
  String? _error;
  String _submittedSearch = '';

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.initialSearch);
    _submittedSearch = widget.initialSearch.trim();
    if (widget.initialGame.isNotEmpty) _filters['game'] = widget.initialGame;
    _load();
  }

  @override
  void didUpdateWidget(covariant ShopScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialGame != widget.initialGame ||
        oldWidget.initialSearch != widget.initialSearch) {
      _debounce?.cancel();
      _search.text = widget.initialSearch;
      _submittedSearch = widget.initialSearch.trim();
      _filters = {
        if (widget.initialGame.isNotEmpty) 'game': widget.initialGame,
      };
      _load();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    if (keyboard > _keyboard && _searchFocus.hasFocus) _revealSearch();
    _keyboard = keyboard;
  }

  void _revealSearch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final field = _searchKey.currentContext;
      if (mounted && field != null && _searchFocus.hasFocus) {
        Scrollable.ensureVisible(field, alignment: 1);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_loading || _more || _page >= _totalPages)) {
      return;
    }
    final request = ++_request;
    setState(() {
      _loading = !more;
      _more = more;
      _retryMore = more;
      _error = null;
    });
    try {
      final result = await widget.api.list({
        ..._filters,
        if (_submittedSearch.isNotEmpty) 'search': _submittedSearch,
        'limit': '12',
        'page': '${more ? _page + 1 : 1}',
      });
      if (!mounted || request != _request) return;
      setState(() {
        final seen = <String>{};
        _items = [
          if (more) ..._items,
          ...result.items,
        ].where((product) => seen.add(product.id)).toList();
        _page = result.page;
        _total = result.total;
        _totalPages = result.totalPages;
      });
    } catch (failure) {
      if (!mounted || request != _request) return;
      setState(
        () => _error = failure is CatalogException
            ? failure.message
            : 'Cards could not be loaded. Try again.',
      );
    } finally {
      if (mounted && request == _request) {
        setState(() {
          _loading = false;
          _more = false;
        });
      }
    }
  }

  void _submitSearch() {
    _debounce?.cancel();
    final value = _search.text.trim();
    if (value == _submittedSearch) return;
    _submittedSearch = value;
    _load();
    if (_searchFocus.hasFocus) {
      _revealSearch();
    } else if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  Future<void> _openFilters() async {
    FocusScope.of(context).unfocus();
    final filters = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: TcgColors.surface,
      builder: (_) => FilterSheet(api: widget.api, filters: _filters),
    );
    if (!mounted || filters == null) return;
    setState(() => _filters = filters);
    _load();
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _removeFilter(String key) {
    setState(() {
      _filters.remove(key);
      if (key == 'game') {
        for (final key in ['set', 'rarity', 'condition']) {
          _filters.remove(key);
        }
      }
    });
    _load();
  }

  void _clearAll() {
    _debounce?.cancel();
    _search.clear();
    _submittedSearch = '';
    setState(() => _filters = {});
    _load();
  }

  String _chipLabel(MapEntry<String, String> entry) {
    return switch (entry.key) {
      'game' => gameLabels[entry.value] ?? entry.value,
      'minPrice' => 'From ₱${entry.value}',
      'maxPrice' => 'Up to ₱${entry.value}',
      'inStock' => 'In stock',
      'sort' => sortLabels[entry.value] ?? entry.value,
      _ => entry.value,
    };
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = constraints.maxWidth < 600 ? 16.0 : 24.0;
        final width = math.min(900.0, constraints.maxWidth - gutter * 2);
        final inset = (constraints.maxWidth - width) / 2;
        final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
        final columns = width < 320 || scale > 1.3
            ? math.max(1, (width / (300 * scale)).floor())
            : width >= 840
            ? 4
            : width >= 620
            ? 3
            : 2;
        final tileWidth = (width - (columns - 1) * 12) / columns;
        final tileHeight = tileWidth * 1.22 + 195 * scale;
        return RefreshIndicator(
          onRefresh: () => _load(),
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(inset, 24, inset, 16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'THE CARD ROOM',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: TcgColors.lavender,
                              letterSpacing: 2,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Find your next card.',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        key: _searchKey,
                        focusNode: _searchFocus,
                        controller: _search,
                        textInputAction: TextInputAction.search,
                        maxLength: 200,
                        onChanged: (_) {
                          setState(() {});
                          _debounce?.cancel();
                          _debounce = Timer(
                            const Duration(milliseconds: 350),
                            _submitSearch,
                          );
                        },
                        onSubmitted: (_) => _submitSearch(),
                        decoration: InputDecoration(
                          labelText: 'Search cards',
                          hintText: 'Name, set or card number',
                          counterText: '',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    setState(() => _search.clear());
                                    _submitSearch();
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _openFilters,
                            icon: const Icon(Icons.tune),
                            label: Text(
                              _filters.isEmpty
                                  ? 'Filter & sort'
                                  : 'Filter & sort (${_filters.length})',
                            ),
                          ),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _loading
                                  ? 'Updating cards…'
                                  : _error != null
                                  ? '${_items.length} cards shown'
                                  : '$_total ${_total == 1 ? 'card' : 'cards'}',
                              style: TextStyle(color: TcgColors.muted),
                            ),
                          ),
                        ],
                      ),
                      if (_filters.isNotEmpty ||
                          _submittedSearch.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (_submittedSearch.isNotEmpty)
                              InputChip(
                                label: Text(
                                  '“$_submittedSearch”',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onDeleted: () {
                                  setState(() => _search.clear());
                                  _submitSearch();
                                },
                              ),
                            for (final filter in _filters.entries)
                              InputChip(
                                label: Text(
                                  _chipLabel(filter),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onDeleted: () => _removeFilter(filter.key),
                              ),
                            TextButton(
                              onPressed: _clearAll,
                              child: const Text('Clear all'),
                            ),
                          ],
                        ),
                      ],
                      if (_loading) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(
                          semanticsLabel: 'Loading cards',
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        StoreMessage(
                          title: 'Catalog unavailable',
                          message: _error!,
                          icon: Icons.wifi_off_outlined,
                          action: 'Try again',
                          onAction: () => _load(more: _retryMore),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (!_loading && _error == null && _items.isEmpty)
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: inset,
                    vertical: 24,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: StoreMessage(
                      title: _filters.isEmpty && _submittedSearch.isEmpty
                          ? 'No cards available'
                          : 'No cards found',
                      message: _filters.isEmpty && _submittedSearch.isEmpty
                          ? 'Check back for new arrivals.'
                          : 'Try another name or broaden your filters.',
                      action: _filters.isEmpty && _submittedSearch.isEmpty
                          ? 'Refresh cards'
                          : 'Clear all',
                      onAction: _filters.isEmpty && _submittedSearch.isEmpty
                          ? () => _load()
                          : _clearAll,
                    ),
                  ),
                ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: inset),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: tileHeight,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => ProductTile(
                      product: _items[index],
                      onTap: () => widget.onProduct(_items[index]),
                    ),
                    childCount: _items.length,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(inset, 20, inset, 32),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: _more
                        ? const CircularProgressIndicator()
                        : !_loading && _error == null && _page < _totalPages
                        ? OutlinedButton.icon(
                            onPressed: () => _load(more: true),
                            icon: const Icon(Icons.add),
                            label: Text(
                              'Load more · ${_items.length} of $_total',
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
