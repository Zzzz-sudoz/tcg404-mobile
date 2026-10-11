import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/commerce_api.dart';
import '../state/auth_state.dart';
import '../state/favorites_state.dart';
import '../theme/app_theme.dart';

class FavoritesScope extends StatefulWidget {
  const FavoritesScope({
    super.key,
    required this.api,
    required this.auth,
    required this.child,
  });
  final CommerceApi api;
  final AuthState auth;
  final Widget child;
  static FavoritesState? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_FavoritesInherited>()
      ?.notifier;
  @override
  State<FavoritesScope> createState() => _FavoritesScopeState();
}

class _FavoritesScopeState extends State<FavoritesScope> {
  late final FavoritesState state = FavoritesState(
    api: widget.api,
    auth: widget.auth,
  );
  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _FavoritesInherited(notifier: state, child: widget.child);
}

class _FavoritesInherited extends InheritedNotifier<FavoritesState> {
  const _FavoritesInherited({required super.notifier, required super.child});
}

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key, required this.product, this.onSignIn});
  final Product product;
  final Future<bool> Function()? onSignIn;
  @override
  Widget build(BuildContext context) {
    final state = FavoritesScope.maybeOf(context);
    if (state == null ||
        state.auth.user?.role == 'admin' ||
        (state.auth.user == null && onSignIn == null)) {
      return const SizedBox.shrink();
    }
    final saved = state.contains(product.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          tooltip:
              '${saved ? 'Remove' : 'Save'} ${product.name} ${saved ? 'from' : 'to'} favorites',
          isSelected: saved,
          color: TcgColors.yellow,
          icon: const Icon(Icons.favorite_border),
          selectedIcon: const Icon(Icons.favorite),
          onPressed: state.loading || state.pending.contains(product.id)
              ? null
              : () async {
                  if (state.auth.user == null) {
                    if (onSignIn == null || !await onSignIn!()) return;
                  }
                  await state.toggle(product.id);
                  if (context.mounted && state.error != null) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(state.error!)));
                  }
                },
        ),
      ],
    );
  }
}
