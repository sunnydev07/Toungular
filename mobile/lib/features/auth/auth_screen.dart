import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/toungular_theme.dart';
import 'auth_repository.dart';
import 'session_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _createAccount = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = ref.read(authRepositoryProvider);
      final session = _createAccount
          ? await repository.register(
              email: _emailController.text,
              password: _passwordController.text,
            )
          : await repository.login(
              email: _emailController.text,
              password: _passwordController.text,
            );
      if (!mounted) return;
      ref.read(sessionControllerProvider.notifier).accept(session);
      context.go(session.profile.needsOnboarding ? '/onboarding' : '/home');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(ToungularSpace.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: ToungularSpace.xl),
                  Container(
                    width: 58,
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ToungularColor.lime,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.record_voice_over_rounded,
                      color: colors.primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: ToungularSpace.l),
                  Text(
                    'Speak into your next chapter.',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: ToungularSpace.s),
                  Text(
                    'Build confidence in English, one useful practice at a time.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: ToungularSpace.xl),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(ToungularSpace.l),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(
                              _createAccount
                                  ? 'Create your account'
                                  : 'Welcome back',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: ToungularSpace.l),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const <String>[
                                AutofillHints.email,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.mail_outline_rounded),
                              ),
                              validator: (value) {
                                final email = value?.trim() ?? '';
                                if (!email.contains('@') ||
                                    email.endsWith('@')) {
                                  return 'Enter a valid email address.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: ToungularSpace.m),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              autofillHints: _createAccount
                                  ? const <String>[AutofillHints.newPassword]
                                  : const <String>[AutofillHints.password],
                              onFieldSubmitted: (_) {
                                if (!_busy) _submit();
                              },
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                prefixIcon: Icon(Icons.lock_outline_rounded),
                              ),
                              validator: (value) {
                                if ((value ?? '').length < 8) {
                                  return 'Use at least 8 characters.';
                                }
                                return null;
                              },
                            ),
                            if (_error != null) ...<Widget>[
                              const SizedBox(height: ToungularSpace.m),
                              Text(
                                _error!,
                                style: TextStyle(color: colors.error),
                              ),
                            ],
                            const SizedBox(height: ToungularSpace.l),
                            FilledButton(
                              onPressed: _busy ? null : _submit,
                              child: _busy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _createAccount
                                          ? 'Create account'
                                          : 'Sign in',
                                    ),
                            ),
                            const SizedBox(height: ToungularSpace.s),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                      _createAccount = !_createAccount;
                                      _error = null;
                                    }),
                              child: Text(
                                _createAccount
                                    ? 'Already have an account? Sign in'
                                    : 'New to Toungular? Create an account',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: ToungularSpace.m),
                  Text(
                    'Your learning profile and practice history stay with your account.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
