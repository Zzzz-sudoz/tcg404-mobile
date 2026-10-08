import 'package:flutter/material.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../services/commerce_api.dart';
import '../state/auth_state.dart';
import '../state/cart_state.dart';
import '../state/checkout_state.dart';
import '../theme/app_theme.dart';
import '../widgets/store_widgets.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.api,
    required this.auth,
    required this.cart,
    required this.onPlaced,
    required this.onOrders,
  });
  final CommerceApi api;
  final AuthState auth;
  final CartState cart;
  final ValueChanged<StoreOrder> onPlaced;
  final VoidCallback onOrders;
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _fields = {
    for (final key in [
      'name',
      'email',
      'phone',
      'address',
      'city',
      'province',
      'postalCode',
      'notes',
    ])
      key: TextEditingController(),
  };
  late final CheckoutState _checkout;
  late final Listenable _changes;
  @override
  void initState() {
    super.initState();
    _checkout = CheckoutState(
      api: widget.api,
      auth: widget.auth,
      cart: widget.cart,
    );
    _changes = Listenable.merge([_checkout, widget.auth, widget.cart]);
    _fields['name']!.text = widget.auth.user?.name ?? '';
    _fields['email']!.text = widget.auth.user?.email ?? '';
    _restore();
  }

  Future<void> _restore() async {
    await _checkout.restore();
    if (!mounted) return;
    for (final entry in _checkout.savedShipping.entries) {
      _fields[entry.key]?.text = entry.value;
    }
    setState(() {});
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    _scroll.dispose();
    _checkout.dispose();
    super.dispose();
  }

  String? _validate(String key, String? value) {
    final text = value?.trim() ?? '';
    if (key == 'notes') {
      return text.length > 500 ? 'Use at most 500 characters.' : null;
    }
    if (text.isEmpty) {
      return 'Enter your ${key == 'postalCode' ? 'postal code' : key}.';
    }
    final max = key == 'address'
        ? 500
        : key == 'email'
        ? 254
        : key == 'phone'
        ? 30
        : 100;
    if (text.length > max) return 'Use at most $max characters.';
    if (key == 'email' &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
      return 'Enter a valid email address.';
    }
    if (key == 'phone' &&
        (!RegExp(r'^[+\d\s().-]+$').hasMatch(text) ||
            text.replaceAll(RegExp(r'\D'), '').length < 7)) {
      return 'Enter a valid phone number.';
    }
    if (key == 'address' && text.length < 5) {
      return 'Enter a complete street address.';
    }
    if (key == 'postalCode' && !RegExp(r'^\d{4}$').hasMatch(text)) {
      return 'Enter a four-digit postal code.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_checkout.busy ||
        (!_checkout.hasPending && !_form.currentState!.validate())) {
      return;
    }
    FocusScope.of(context).unfocus();
    final order = await _checkout.submit({
      for (final entry in _fields.entries) entry.key: entry.value.text.trim(),
      'country': 'Philippines',
    });
    if (!mounted) return;
    if (order != null) {
      widget.onPlaced(order);
    } else if (_scroll.hasClients) {
      await _scroll.animateTo(
        0,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _field(
    String key,
    String label, {
    TextInputType? keyboard,
    int lines = 1,
    Iterable<String>? autofillHints,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: _fields[key],
      enabled: !_checkout.busy && !_checkout.hasPending,
      keyboardType: keyboard,
      maxLines: lines,
      autofillHints: autofillHints,
      textInputAction: lines > 1
          ? TextInputAction.newline
          : TextInputAction.next,
      decoration: InputDecoration(labelText: label),
      validator: (value) => _validate(key, value),
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _changes,
    builder: (context, child) => PopScope(
      canPop: !_checkout.busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: StoreBackdrop(
          child: SafeArea(
            child: !_checkout.ready
                ? const Center(child: CircularProgressIndicator())
                : widget.auth.user?.id != _checkout.ownerId ||
                      widget.auth.user == null
                ? StoreMessage(
                    title: 'Sign in to continue',
                    message:
                        'Your cart is saved. Return to it and sign in to check your order.',
                    icon: Icons.lock_outline,
                    action: 'Return to cart',
                    onAction: () => Navigator.pop(context),
                  )
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: AutofillGroup(
                        child: Form(
                          key: _form,
                          child: SingleChildScrollView(
                            controller: _scroll,
                            padding: const EdgeInsets.all(24),
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'MAKE IT YOURS.',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineLarge,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'A few delivery details. A new place in your collection.',
                                  style: TextStyle(color: TcgColors.muted),
                                ),
                                const SizedBox(height: 24),
                                if (_checkout.error != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    child: Semantics(
                                      liveRegion: true,
                                      child: Text(
                                        _checkout.error!,
                                        style: const TextStyle(
                                          color: TcgColors.red,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (_checkout.recoveryFailed)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: OutlinedButton(
                                      onPressed: _checkout.busy
                                          ? null
                                          : _restore,
                                      child: const Text(
                                        'Retry checkout recovery',
                                      ),
                                    ),
                                  ),
                                if (_checkout.hasPending)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'YOUR SAVED SUBMISSION',
                                          style: TextStyle(
                                            color: TcgColors.yellow,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'The delivery details and cards below belong to your original submission. Retry to retrieve its confirmation.',
                                          style: TextStyle(
                                            color: TcgColors.muted,
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: _checkout.busy
                                              ? null
                                              : widget.onOrders,
                                          child: const Text('Check my orders'),
                                        ),
                                      ],
                                    ),
                                  ),
                                Text(
                                  'Delivery',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 16),
                                _field(
                                  'name',
                                  'Full name',
                                  autofillHints: const [AutofillHints.name],
                                ),
                                _field(
                                  'email',
                                  'Email address',
                                  keyboard: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email],
                                ),
                                _field(
                                  'phone',
                                  'Phone number',
                                  keyboard: TextInputType.phone,
                                  autofillHints: const [
                                    AutofillHints.telephoneNumber,
                                  ],
                                ),
                                _field(
                                  'address',
                                  'Street address',
                                  lines: 2,
                                  keyboard: TextInputType.streetAddress,
                                  autofillHints: const [
                                    AutofillHints.streetAddressLine1,
                                  ],
                                ),
                                _field(
                                  'city',
                                  'City / municipality',
                                  autofillHints: const [
                                    AutofillHints.addressCity,
                                  ],
                                ),
                                _field(
                                  'province',
                                  'Province',
                                  autofillHints: const [
                                    AutofillHints.addressState,
                                  ],
                                ),
                                _field(
                                  'postalCode',
                                  'Postal code',
                                  keyboard: TextInputType.number,
                                  autofillHints: const [
                                    AutofillHints.postalCode,
                                  ],
                                ),
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 20),
                                  child: Text(
                                    'Country · Philippines',
                                    style: TextStyle(color: TcgColors.muted),
                                  ),
                                ),
                                _field(
                                  'notes',
                                  'Delivery notes (optional)',
                                  lines: 2,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Your singles',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: TcgColors.surface.withValues(
                                      alpha: .9,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: TcgColors.border),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      for (final item in _checkout.summaryItems)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: Wrap(
                                            alignment:
                                                WrapAlignment.spaceBetween,
                                            spacing: 16,
                                            runSpacing: 4,
                                            children: [
                                              Text(
                                                '${item['quantity']} × ${item['name']}',
                                              ),
                                              Text(
                                                money(
                                                  priceToCents(
                                                        (item['price'] as num)
                                                            .toDouble(),
                                                      ) *
                                                      (item['quantity']
                                                          as int) /
                                                      100,
                                                ),
                                                style: const TextStyle(
                                                  color: TcgColors.yellow,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      const Divider(),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        alignment: WrapAlignment.spaceBetween,
                                        spacing: 16,
                                        runSpacing: 4,
                                        children: [
                                          const Text('Items subtotal'),
                                          Text(
                                            money(
                                              _checkout.summarySubtotalCents /
                                                  100,
                                            ),
                                            style: const TextStyle(
                                              color: TcgColors.yellow,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'The store confirms the final delivery charges and total with your receipt.',
                                        style: TextStyle(
                                          color: TcgColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (widget.cart.notice != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Text(
                                      widget.cart.notice!,
                                      style: const TextStyle(
                                        color: TcgColors.yellow,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 24),
                                FilledButton.icon(
                                  onPressed:
                                      _checkout.busy ||
                                          _checkout.recoveryFailed ||
                                          (!_checkout.hasPending &&
                                              !widget.cart.valid)
                                      ? null
                                      : _submit,
                                  icon: const Icon(Icons.shopping_bag_outlined),
                                  label: Text(
                                    _checkout.busy
                                        ? 'Confirming order…'
                                        : _checkout.hasPending
                                        ? 'Retry saved submission'
                                        : 'Place order',
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    ),
  );
}
