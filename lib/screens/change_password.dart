import 'package:flutter/material.dart';
import '../services/commerce_api.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';

class ChangePassword extends StatefulWidget {
  const ChangePassword({super.key, required this.api, required this.auth});
  final CommerceApi api;
  final AuthState auth;
  @override
  State<ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePassword> {
  final _form = GlobalKey<FormState>();
  final _fields = {
    for (final key in ['oldPassword', 'newPassword', 'confirmPassword'])
      key: TextEditingController(),
  };
  final _visible = <String>{};
  bool _editing = false, _busy = false;
  String? _error;
  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    final revision = widget.auth.revision;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.request(
        'PATCH',
        'auth/password',
        body: {
          for (final entry in _fields.entries) entry.key: entry.value.text,
        },
      );
      if (!mounted || revision != widget.auth.revision) return;
      for (final field in _fields.values) {
        field.clear();
      }
      setState(() => _editing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Password updated.')));
    } catch (error) {
      if (!mounted || revision != widget.auth.revision) return;
      if (error is ApiFailure && error.statusCode == 401) {
        widget.auth.expire();
        return;
      }
      setState(
        () => _error = error is ApiFailure
            ? error.message
            : 'Password could not be updated. Try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _validate(String key, String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Complete this field.';
    if (key == 'newPassword' &&
        (text.length < 5 ||
            text.length > 128 ||
            !RegExp(r'[A-Z]').hasMatch(text) ||
            !RegExp(r'[0-9]').hasMatch(text) ||
            !RegExp(r'[^A-Za-z0-9\s]').hasMatch(text))) {
      return 'Use 5–128 characters, an uppercase letter, number and special character.';
    }
    if (key == 'newPassword' && text == _fields['oldPassword']!.text) {
      return 'Choose a different password.';
    }
    if (key == 'confirmPassword' && text != _fields['newPassword']!.text) {
      return 'Passwords must match.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 24),
      const Text('Password'),
      const Text('••••••••'),
      if (!_editing)
        OutlinedButton(
          onPressed: () => setState(() => _editing = true),
          child: const Text('Change password'),
        ),
      if (_editing)
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: TcgColors.of(context).red),
                ),
              for (final entry in {
                'oldPassword': 'Current password',
                'newPassword': 'New password',
                'confirmPassword': 'Confirm new password',
              }.entries)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextFormField(
                    controller: _fields[entry.key],
                    enabled: !_busy,
                    obscureText: !_visible.contains(entry.key),
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: entry.value,
                      suffixIcon: IconButton(
                        tooltip: _visible.contains(entry.key)
                            ? 'Hide ${entry.value.toLowerCase()}'
                            : 'Show ${entry.value.toLowerCase()}',
                        onPressed: () => setState(() {
                          if (!_visible.add(entry.key)) {
                            _visible.remove(entry.key);
                          }
                        }),
                        icon: Icon(
                          _visible.contains(entry.key)
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                    validator: (v) => _validate(entry.key, v),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Saving...' : 'Update password'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        for (final field in _fields.values) {
                          field.clear();
                        }
                        _editing = false;
                        _error = null;
                      }),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
    ],
  );
}
