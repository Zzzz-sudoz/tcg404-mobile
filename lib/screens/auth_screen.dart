import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/store_widgets.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.auth, this.register = false});
  final AuthState auth;
  final bool register;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _visible = false;
  late bool _register = widget.register;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.auth.busy || !_form.currentState!.validate()) return;
    setState(() => _error = null);
    final error = _register
        ? await widget.auth.register(_name.text, _email.text, _password.text)
        : await widget.auth.login(_email.text, _password.text);
    if (!mounted) return;
    if (error == null) {
      TextInput.finishAutofillContext();
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_register ? 'Create account' : 'Sign in')),
    body: StoreBackdrop(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ListenableBuilder(
                listenable: widget.auth,
                builder: (context, child) => AutofillGroup(
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _register
                              ? 'YOUR NEXT CHAPTER.'
                              : 'BACK TO YOUR COLLECTION.',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _register
                              ? 'Create your TCG404 account to manage your profile and orders.'
                              : 'Sign in to view your profile and orders.',
                          style: const TextStyle(color: TcgColors.muted),
                        ),
                        const SizedBox(height: 32),
                        if (_register) ...[
                          TextFormField(
                            controller: _name,
                            enabled: !widget.auth.busy,
                            autofillHints: const [AutofillHints.name],
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            maxLength: 100,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Enter your name.'
                                : null,
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: _email,
                          enabled: !widget.auth.busy,
                          autofillHints: const [AutofillHints.email],
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            return email.length > 254 ||
                                    !RegExp(
                                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                    ).hasMatch(email)
                                ? 'Enter a valid email address.'
                                : null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _password,
                          enabled: !widget.auth.busy,
                          autofillHints: [
                            _register
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          obscureText: !_visible,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            helperText: _register
                                ? 'Use 8 to 128 characters.'
                                : null,
                            suffixIcon: IconButton(
                              tooltip: _visible
                                  ? 'Hide password'
                                  : 'Show password',
                              onPressed: () =>
                                  setState(() => _visible = !_visible),
                              icon: Icon(
                                _visible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            final length = value?.length ?? 0;
                            if (length == 0) return 'Enter your password.';
                            if (length > 128 || (_register && length < 8)) {
                              return _register
                                  ? 'Use 8 to 128 characters.'
                                  : 'Use no more than 128 characters.';
                            }
                            return null;
                          },
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              style: const TextStyle(color: TcgColors.red),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: widget.auth.busy ? null : _submit,
                          child: Text(
                            widget.auth.busy
                                ? 'Please wait...'
                                : _register
                                ? 'Create account'
                                : 'Sign in',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: widget.auth.busy
                              ? null
                              : () => setState(() {
                                  _register = !_register;
                                  _error = null;
                                  _form.currentState?.reset();
                                }),
                          child: Text(
                            _register
                                ? 'Already have an account? Sign in'
                                : 'New to TCG404? Create an account',
                          ),
                        ),
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
  );
}
