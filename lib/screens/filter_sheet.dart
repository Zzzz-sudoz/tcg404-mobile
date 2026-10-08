import 'package:flutter/material.dart';

import '../services/catalog_api.dart';
import '../theme/app_theme.dart';

const gameLabels = {
  'pokemon': 'Pokémon',
  'one-piece': 'One Piece',
  'magic': 'Magic: The Gathering',
};

const sortLabels = {
  'newest': 'Newest arrivals',
  'price-asc': 'Price: low to high',
  'price-desc': 'Price: high to low',
  'name-asc': 'Name: A to Z',
  'name-desc': 'Name: Z to A',
};

class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key, required this.api, required this.filters});

  final CatalogApi api;
  final Map<String, String> filters;

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  final _form = GlobalKey<FormState>();
  late Map<String, String> _draft;
  late final TextEditingController _min;
  late final TextEditingController _max;
  Map<String, List<String>> _facets = {};
  bool _loading = true;
  bool _failed = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _draft = Map.of(widget.filters);
    _min = TextEditingController(text: _draft['minPrice']);
    _max = TextEditingController(text: _draft['maxPrice']);
    _fetchFacets();
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _fetchFacets() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _failed = false;
      _facets = {};
    });
    try {
      final result = await widget.api.list({
        'limit': '1',
        if (_draft['game'] case final String game) 'game': game,
      });
      if (!mounted || request != _request) return;
      setState(() => _facets = result.facets);
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() => _failed = true);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  void _set(String key, String? value) {
    setState(() {
      if (value == null || value.isEmpty) {
        _draft.remove(key);
      } else {
        _draft[key] = value;
      }
      if (key == 'game') {
        for (final field in ['set', 'rarity', 'condition']) {
          _draft.remove(field);
        }
      }
    });
    if (key == 'game') _fetchFacets();
  }

  void _clear() {
    setState(() {
      _draft.clear();
      _min.clear();
      _max.clear();
      _form.currentState?.reset();
    });
    _fetchFacets();
  }

  String? _validatePrice(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final number = double.tryParse(value.trim());
    if (number == null || !number.isFinite || number < 0) {
      return 'Enter a valid price of 0 or more.';
    }
    return null;
  }

  void _apply() {
    if (!_form.currentState!.validate()) return;
    for (final entry in {
      'minPrice': _min.text,
      'maxPrice': _max.text,
    }.entries) {
      if (entry.value.trim().isEmpty) {
        _draft.remove(entry.key);
      } else {
        _draft[entry.key] = entry.value.trim();
      }
    }
    Navigator.pop(context, _draft);
  }

  Widget _select(
    String key,
    String label,
    Map<String, String> options, {
    bool enabled = true,
  }) {
    final value = _draft[key] ?? '';
    final choices = {'': 'All ${label.toLowerCase()}', ...options};
    if (value.isNotEmpty && !choices.containsKey(value)) choices[value] = value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        key: ValueKey('$key:$value'),
        initialValue: value,
        isExpanded: true,
        itemHeight: null,
        menuMaxHeight: 320,
        decoration: InputDecoration(labelText: label),
        items: choices.entries
            .map(
              (entry) => DropdownMenuItem(
                value: entry.key,
                child: Text(
                  entry.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: enabled ? (value) => _set(key, value) : null,
      ),
    );
  }

  Widget _facet(String key, String label, String facet) {
    return _select(key, label, {
      for (final value in _facets[facet] ?? <String>[]) value: value,
    }, enabled: !_loading && !_failed);
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .88 - keyboard * .5,
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filter & sort',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close filters without applying',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              SizedBox(
                child: Form(
                  key: _form,
                  child: ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      _select('game', 'Games', gameLabels),
                      if (_loading) ...[
                        const LinearProgressIndicator(),
                        const SizedBox(height: 8),
                        const Text('Loading available filters…'),
                        const SizedBox(height: 16),
                      ],
                      if (_failed) ...[
                        const Text(
                          'Set, rarity and condition filters could not be loaded.',
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _fetchFacets,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry filters'),
                          ),
                        ),
                      ],
                      _facet('set', 'Sets', 'sets'),
                      _facet('rarity', 'Rarities', 'rarities'),
                      _facet('condition', 'Conditions', 'conditions'),
                      Text(
                        'Selling price · PHP',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _min,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Minimum price',
                          prefixText: '₱ ',
                        ),
                        validator: _validatePrice,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _max,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Maximum price',
                          prefixText: '₱ ',
                        ),
                        validator: (value) {
                          final invalid = _validatePrice(value);
                          if (invalid != null) return invalid;
                          final min = double.tryParse(_min.text.trim());
                          final max = double.tryParse(value?.trim() ?? '');
                          if (min != null && max != null && max < min) {
                            return 'Maximum must be at least the minimum.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('In stock only'),
                        subtitle: const Text('Cards available to add to cart'),
                        value: _draft['inStock'] == 'true',
                        onChanged: (value) =>
                            _set('inStock', value ? 'true' : null),
                      ),
                      const SizedBox(height: 8),
                      _select('sort', 'Sort order', sortLabels),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: TcgColors.border)),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _clear,
                      child: const Text('Clear all'),
                    ),
                    FilledButton(
                      onPressed: _apply,
                      child: const Text('Apply filters'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
