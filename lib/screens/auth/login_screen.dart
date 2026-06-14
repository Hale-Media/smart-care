import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _pin = TextEditingController();

  @override
  void dispose() {
    _tabs.dispose();
    _email.dispose();
    _password.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submitPassword() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await context
        .read<AuthProvider>()
        .login(_email.text.trim(), _password.text);
    if (!ok && mounted) _showError();
  }

  Future<void> _submitPin() async {
    if (_pin.text.length < 4) return;
    final ok = await context.read<AuthProvider>().loginWithPin(_pin.text);
    if (!ok && mounted) _showError();
  }

  void _showError() {
    final err = context.read<AuthProvider>().error ?? 'Sign in failed';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Image.asset('assets/images/logo.png', height: 80),
                  const SizedBox(height: 12),
                  const Text(AppConfig.appName,
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const Text('Care home resident monitoring',
                      style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TabBar(
                            controller: _tabs,
                            labelColor: AppTheme.primary,
                            tabs: const [
                              Tab(text: 'Password'),
                              Tab(text: 'Quick PIN'),
                            ],
                          ),
                          SizedBox(
                            height: 260,
                            child: TabBarView(
                              controller: _tabs,
                              children: [
                                _passwordForm(auth),
                                _pinForm(auth),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('New to Care Package?',
                          style: TextStyle(color: Colors.black54)),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        ),
                        child: const Text('Create account'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordForm(AuthProvider auth) {
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
              validator: Validators.email,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
              validator: (v) => Validators.required(v, 'Password'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: auth.busy ? null : _submitPassword,
              child: auth.busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pinForm(AuthProvider auth) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          const Text('Enter your 4–6 digit shift PIN',
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _pin,
            keyboardType: TextInputType.number,
            obscureText: true,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: const TextStyle(fontSize: 24, letterSpacing: 8),
            decoration: const InputDecoration(counterText: ''),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: auth.busy ? null : _submitPin,
            child: const Text('Sign in with PIN'),
          ),
        ],
      ),
    );
  }
}
