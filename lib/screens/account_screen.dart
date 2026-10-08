import 'package:flutter/material.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.auth,
    required this.onSignIn,
    required this.onRegister,
    required this.onOrders,
  });
  final AuthState auth;
  final VoidCallback onSignIn, onRegister, onOrders;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  int? _revision;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || widget.auth.busy) return;
    final error = await widget.auth.updateName(_name.text);
    if (!mounted) return;
    if (error == null) {
      _name.text = widget.auth.user!.name;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your name has been updated.')),
      );
    }
  }

  Future<void> _logout() async {
    final revision = widget.auth.revision;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.logout, color: TcgColors.red),
        title: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: TcgColors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted && revision == widget.auth.revision) {
      await widget.auth.logout();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.auth,
    builder: (context, child) {
      final auth = widget.auth;
      if (!auth.ready) {
        return const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading account'),
        );
      }
      final user = auth.user;
      if (_revision != auth.revision) {
        _revision = auth.revision;
        _name.text = user?.name ?? '';
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'YOUR COLLECTOR SPACE.',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 16),
                if (auth.error != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      auth.error!,
                      style: const TextStyle(color: TcgColors.red),
                    ),
                  ),
                  if (auth.restoreFailed)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: auth.busy ? null : auth.restore,
                        child: const Text('Retry account connection'),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
                if (user == null) ...[
                  const Text(
                    'Sign in to manage your profile and follow your orders.',
                    style: TextStyle(color: TcgColors.muted),
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: auth.busy ? null : widget.onSignIn,
                    child: const Text('Sign in'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: auth.busy ? null : widget.onRegister,
                    child: const Text('Create account'),
                  ),
                ] else ...[
                  Text(
                    'Edit account',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _name,
                          enabled: !auth.busy,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.name],
                          maxLength: 100,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _save(),
                          decoration: InputDecoration(
                            labelText: 'Name',
                            errorText: auth.fields['name'],
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter your name.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Email address',
                          style: TextStyle(color: TcgColors.muted),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(user.email),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: auth.busy ? null : _save,
                          child: Text(
                            auth.busy ? 'Please wait...' : 'Save changes',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: auth.busy ? null : widget.onOrders,
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Orders & tracking'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: TcgColors.red,
                      side: const BorderSide(color: TcgColors.red),
                    ),
                    onPressed: auth.busy ? null : _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
