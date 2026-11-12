import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/toungular_theme.dart';
import 'profile_repository.dart';
import 'session_controller.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});
  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your Toungular account?'),
        content: const Text(
          'Your profile, lesson history, vocabulary reviews, practice transcripts, and saved conversations will be deleted from Toungular.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep account'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).deleteAccount();
      await ref.read(sessionControllerProvider.notifier).signOut();
      if (mounted) context.go('/auth');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Your account could not be deleted. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(sessionControllerProvider).session?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(ToungularSpace.l),
        children: <Widget>[
          Text(
            'Your Toungular account',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: ToungularSpace.s),
          Text(email),
          const SizedBox(height: ToungularSpace.xl),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    await ref
                        .read(sessionControllerProvider.notifier)
                        .signOut();
                    if (context.mounted) context.go('/auth');
                  },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
          const SizedBox(height: ToungularSpace.xl),
          Text('Delete account', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: ToungularSpace.xs),
          const Text(
            'This deletes your Toungular account and learning records. Purchases and financial records, if ever enabled, may be subject to separate legal retention rules.',
          ),
          const SizedBox(height: ToungularSpace.s),
          FilledButton.tonalIcon(
            onPressed: _busy ? null : _deleteAccount,
            icon: const Icon(Icons.delete_forever_outlined),
            label: Text(_busy ? 'Deleting…' : 'Delete my account'),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: ToungularSpace.s),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
