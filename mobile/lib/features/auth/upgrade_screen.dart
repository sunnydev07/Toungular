import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/toungular_theme.dart';
import 'auth_repository.dart';
import 'session_controller.dart';

/// Turns the guest session on this device into a permanent account, so the
/// lessons, reviews, and practice already done are kept.
class UpgradeScreen extends ConsumerStatefulWidget {
  const UpgradeScreen({super.key});

  @override
  ConsumerState<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends ConsumerState<UpgradeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
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
      final session = await ref
          .read(authRepositoryProvider)
          .upgradeGuest(
            email: _emailController.text,
            password: _passwordController.text,
          );
      if (!mounted) return;
      ref.read(sessionControllerProvider.notifier).accept(session);
      context.go(session.profile.needsOnboarding ? '/onboarding' : '/home');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Your account could not be created. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Create your account')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(ToungularSpace.l),
              children: <Widget>[
                Text(
                  'Keep your guest progress',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: ToungularSpace.s),
                Text(
                  'Add an email and password to keep this device\'s lessons, reviews, and practice history — and to use Toungular Plus and referrals.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: ToungularSpace.l),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(ToungularSpace.l),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const <String>[AutofillHints.email],
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
                            autofillHints: const <String>[
                              AutofillHints.newPassword,
                            ],
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
                                : const Text('Create my account'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
