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
  final _confirm = TextEditingController();
  bool _visible = false;
  late bool _register = widget.register;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
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
                    autovalidateMode: AutovalidateMode.onUserInteraction,
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
                          autofillHints: [
                            _register
                                ? AutofillHints.email
                                : AutofillHints.username,
                          ],
                          keyboardType: _register
                              ? TextInputType.emailAddress
                              : TextInputType.text,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: _register
                                ? 'Email address'
                                : 'Email or username',
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (!_register) {
                              return email.isEmpty || email.length > 254
                                  ? 'Enter your email or username.'
                                  : null;
                            }
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
                          onChanged: (_) => setState(() {}),
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Password',
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
                            if (length > 128 || (_register && length < 5)) {
                              return _register
                                  ? 'Use 5 to 128 characters.'
                                  : 'Use no more than 128 characters.';
                            }
                            if (_register &&
                                (!RegExp(r'[A-Z]').hasMatch(value!) ||
                                    !RegExp(r'[0-9]').hasMatch(value) ||
                                    !RegExp(
                                      r'[^A-Za-z0-9\s]',
                                    ).hasMatch(value))) {
                              return 'Include an uppercase letter, number and special character.';
                            }
                            return null;
                          },
                        ),
                        if (_register) ...[
                          const SizedBox(height: 12),
                          for (final rule in <String, bool>{
                            '5 to 128 characters':
                                _password.text.length >= 5 &&
                                _password.text.length <= 128,
                            'One uppercase letter': RegExp(
                              r'[A-Z]',
                            ).hasMatch(_password.text),
                            'One number': RegExp(
                              r'[0-9]',
                            ).hasMatch(_password.text),
                            'One special character': RegExp(
                              r'[^A-Za-z0-9\s]',
                            ).hasMatch(_password.text),
                          }.entries)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Icon(
                                    rule.value
                                        ? Icons.check_circle_outline
                                        : Icons.circle_outlined,
                                    size: 18,
                                    color: rule.value
                                        ? TcgColors.of(context).yellow
                                        : TcgColors.of(context).muted,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      rule.key,
                                      style: TextStyle(
                                        color: rule.value
                                            ? TcgColors.of(context).yellow
                                            : TcgColors.of(context).muted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirm,
                            enabled: !widget.auth.busy,
                            obscureText: !_visible,
                            autocorrect: false,
                            enableSuggestions: false,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            decoration: const InputDecoration(
                              labelText: 'Confirm password',
                            ),
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            validator: (value) =>
                                value != _password.text ||
                                    (value?.isEmpty ?? true)
                                ? 'Passwords must match.'
                                : null,
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: TcgColors.of(context).red,
                              ),
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
                                : "Don't have an account? Sign up",
                            textAlign: TextAlign.center,
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
