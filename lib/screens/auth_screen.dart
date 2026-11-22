import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose(); _password.dispose(); _first.dispose(); _last.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate() || _busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      if (_register) {
        await AuthService().register(email: _email.text, password: _password.text,
            firstName: _first.text, lastName: _last.text);
      } else {
        await AuthService().signIn(_email.text, _password.text);
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campus Board')),
      body: Center(child: SingleChildScrollView(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(padding: const EdgeInsets.all(20), child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Icon(_register ? Icons.person_add_alt : Icons.forum_rounded,
                size: 58, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(_register ? 'Create an account' : 'Welcome back',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            if (_register) ...[
              TextFormField(controller: _first, decoration: const InputDecoration(labelText: 'First name'),
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Enter your first name' : null),
              TextFormField(controller: _last, decoration: const InputDecoration(labelText: 'Last name'),
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Enter your last name' : null),
            ],
            TextFormField(controller: _email, keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v?.trim() ?? '')
                    ? null : 'Enter a valid email'),
            TextFormField(controller: _password, obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (v) => (v?.length ?? 0) < 6 ? 'Use at least 6 characters' : null),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 14),
                child: Text(_error!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 20),
            FilledButton(onPressed: _busy ? null : _submit,
                child: Padding(padding: const EdgeInsets.all(12),
                    child: Text(_busy ? 'Please wait...' : (_register ? 'Register' : 'Sign in')))),
            TextButton(onPressed: _busy ? null : () => setState(() {
              _register = !_register; _error = null; _form.currentState?.reset();
              _email.clear(); _password.clear(); _first.clear(); _last.clear();
            }), child: Text(_register ? 'Already have an account? Sign in'
                : 'New here? Register')),
          ]),
        )),
      ))),
    );
  }
}
