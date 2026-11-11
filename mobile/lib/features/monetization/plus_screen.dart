import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/toungular_theme.dart';
import '../../shared/models/learning_models.dart';
import 'monetization_repository.dart';

class ToungularPlusScreen extends ConsumerStatefulWidget {
  const ToungularPlusScreen({super.key});
  @override
  ConsumerState<ToungularPlusScreen> createState() =>
      _ToungularPlusScreenState();
}

class _ToungularPlusScreenState extends ConsumerState<ToungularPlusScreen> {
  late Future<(EntitlementSnapshot, ReferralSummary)> _data;
  final _codeController = TextEditingController();
  bool _busy = false;
  String? _message;
  String? _error;

  Future<(EntitlementSnapshot, ReferralSummary)> _load() async {
    final repository = ref.read(monetizationRepositoryProvider);
    final values = await Future.wait<Object>(<Future<Object>>[
      repository.entitlements(),
      repository.referral(),
    ]);
    return (values[0] as EntitlementSnapshot, values[1] as ReferralSummary);
  }

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    if (_codeController.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await ref
          .read(monetizationRepositoryProvider)
          .redeem(_codeController.text.trim());
      if (mounted)
        setState(() {
          _message = 'Referral code saved.';
          _codeController.clear();
          _data = _load();
        });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'This code could not be redeemed. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await ref.read(monetizationRepositoryProvider).restore();
      if (mounted)
        setState(() {
          _message = 'Purchase restore complete.';
          _data = _load();
        });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Purchase restore is unavailable.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Toungular Plus')),
    body: FutureBuilder<(EntitlementSnapshot, ReferralSummary)>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) {
          final error = snapshot.error;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(ToungularSpace.l),
              child: Text(
                error is ApiException
                    ? error.message
                    : 'Account options could not load.',
              ),
            ),
          );
        }
        final entitlement = snapshot.data!.$1;
        final referral = snapshot.data!.$2;
        return ListView(
          padding: const EdgeInsets.all(ToungularSpace.l),
          children: <Widget>[
            Text(
              entitlement.premium
                  ? 'You are on Plus.'
                  : 'More room to practice.',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: ToungularSpace.s),
            Text(
              entitlement.premium
                  ? 'Your Toungular Plus entitlement is active.'
                  : 'Toungular Plus will offer extended practice and an ad-free learning space when account billing is configured.',
            ),
            const SizedBox(height: ToungularSpace.l),
            Card(
              color: ToungularColor.ink,
              child: Padding(
                padding: const EdgeInsets.all(ToungularSpace.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Toungular Plus',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: ToungularSpace.m),
                    const Text(
                      '• Extended speaking and coach practice\n• Ads removed from learning screens\n• Progress tools for a steady study routine',
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: ToungularSpace.l),
                    const Text(
                      'Purchases are not available yet. Toungular must configure its own Play products and server verification before accepting payment.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: ToungularSpace.m),
                    FilledButton(
                      onPressed: null,
                      child: Text(
                        entitlement.premium
                            ? 'Plus active'
                            : 'Purchase not configured',
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _restore,
                      child: const Text('Restore purchases'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: ToungularSpace.l),
            Text(
              'Invite a learning partner',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: ToungularSpace.s),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(ToungularSpace.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Your referral code',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: ToungularSpace.s),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: SelectableText(
                            referral.code,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy referral code',
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: referral.code),
                            );
                            if (context.mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Code copied.')),
                              );
                          },
                          icon: const Icon(Icons.copy),
                        ),
                      ],
                    ),
                    Text(
                      '${referral.referredCount} people joined with your code.',
                    ),
                    const SizedBox(height: ToungularSpace.xs),
                    Text(
                      referral.reward,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: ToungularSpace.l),
                    TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Enter a referral code',
                      ),
                    ),
                    const SizedBox(height: ToungularSpace.s),
                    FilledButton(
                      onPressed: _busy || referral.redeemed ? null : _redeem,
                      child: Text(
                        referral.redeemed
                            ? 'Code already used'
                            : _busy
                            ? 'Saving…'
                            : 'Redeem code',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_message != null) ...<Widget>[
              const SizedBox(height: ToungularSpace.s),
              Text(
                _message!,
                style: const TextStyle(color: ToungularColor.leaf),
              ),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: ToungularSpace.s),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        );
      },
    ),
  );
}
