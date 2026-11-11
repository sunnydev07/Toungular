import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/toungular_theme.dart';
import '../../shared/models/learning_models.dart';
import 'mastery_repository.dart';

class MasteryScreen extends ConsumerStatefulWidget {
  const MasteryScreen({super.key});

  @override
  ConsumerState<MasteryScreen> createState() => _MasteryScreenState();
}

class _MasteryScreenState extends ConsumerState<MasteryScreen> {
  MasteryProfile? _profile;
  bool _loading = true;
  bool _usingToken = false;
  String? _error;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repository = ref.read(masteryRepositoryProvider);
      final profile = await repository.getProfile();

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load mastery profile: $e';
      });
    }
  }

  Future<void> _useToken() async {
    if (_profile == null || _profile!.freezeTokens <= 0 || _usingToken) return;

    setState(() {
      _usingToken = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final repository = ref.read(masteryRepositoryProvider);
      final updated = await repository.useFreezeToken();

      if (!mounted) return;
      setState(() {
        _profile = updated;
        _usingToken = false;
        _successMessage = 'Streak Freeze applied! Your daily streak is protected.';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _usingToken = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _usingToken = false;
        _error = 'Failed to use freeze token: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mastery & Skill XP')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mastery & Skill XP')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Unable to retrieve mastery profile.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _loadProfile, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final p = _profile!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mastery Profile'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadProfile,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Hero Rank Tier Card
            Card(
              color: ToungularColor.ink,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: ToungularColor.lime,
                          child: Text(
                            'L${p.level}',
                            style: const TextStyle(
                              color: ToungularColor.ink,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.rankTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${p.totalXp} Total Skill XP',
                                style: const TextStyle(
                                  color: ToungularColor.lime,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: p.levelProgressPercent / 100.0,
                        minHeight: 10,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(ToungularColor.lime),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${p.levelProgressPercent}% completed',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                        ),
                        Text(
                          p.nextLevelXpRequired > 0
                              ? '${p.nextLevelXpRequired} XP to Level ${p.level + 1}'
                              : 'Maximum Rank Attained',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 28),

                    Row(
                      children: [
                        const Icon(Icons.star_outline, color: ToungularColor.lime, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Perk: ${p.perk}',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Freeze Tokens & Anti-Anxiety Streak Safeguard
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ToungularColor.mist,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.ac_unit, color: ToungularColor.leaf, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p.freezeTokens} Freeze Tokens',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Protects streaks without punishment anxiety (Deci & Ryan Autonomy)',
                            style: TextStyle(color: ToungularColor.mutedInk, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ToungularColor.leaf,
                        side: const BorderSide(color: ToungularColor.leaf),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: p.freezeTokens > 0 && !_usingToken ? _useToken : null,
                      child: _usingToken
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Use'),
                    ),
                  ],
                ),
              ),
            ),

            if (_successMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ToungularColor.mist,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: ToungularColor.leaf, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(color: ToungularColor.leaf, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],

            const SizedBox(height: 20),
            Text(
              '4-Axis Skill Mastery Breakdown',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'Grounded in Self-Determination Theory: competence increases across distinct communicative dimensions.',
              style: TextStyle(color: ToungularColor.mutedInk, fontSize: 13),
            ),
            const SizedBox(height: 14),

            // 4 Skill Cards
            _buildSkillAxisCard(
              title: 'Fluency & Pacing',
              xp: p.fluencyXp,
              color: const Color(0xFF1D6C57),
              icon: Icons.speed,
              description: 'Speech tempo (WPM), pause composure, and continuous narrative flow.',
              actionLabel: 'Practice Speaking',
              onAction: () => context.push('/speaking'),
            ),
            const SizedBox(height: 10),

            _buildSkillAxisCard(
              title: 'Lexical Breadth',
              xp: p.lexicalXp,
              color: const Color(0xFF6366F1),
              icon: Icons.auto_stories,
              description: 'Spaced repetition recall, tier 2/3 vocabulary acquisition, and cloze mastery.',
              actionLabel: 'Review SRS Words',
              onAction: () => context.push('/vocabulary'),
            ),
            const SizedBox(height: 10),

            _buildSkillAxisCard(
              title: 'Acoustic Precision',
              xp: p.acousticXp,
              color: const Color(0xFFE86B4B),
              icon: Icons.graphic_eq,
              description: 'Phoneme minimal pairs discrimination, IPA tongue placement, and speech shadowing.',
              actionLabel: 'Phoneme Lab',
              onAction: () => context.push('/pronunciation'),
            ),
            const SizedBox(height: 10),

            _buildSkillAxisCard(
              title: 'Interactive Agility',
              xp: p.interactionXp,
              color: const Color(0xFF0EA5E9),
              icon: Icons.forum_outlined,
              description: 'Conversational turns with AI Coach, real-time recasts, and communicative confidence.',
              actionLabel: 'Chat with Coach',
              onAction: () => context.push('/coach'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillAxisCard({
    required String title,
    required int xp,
    required Color color,
    required IconData icon,
    required String description,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: ToungularColor.sand),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('$xp XP', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onAction,
                  child: Text(
                    actionLabel,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(color: ToungularColor.mutedInk, fontSize: 13, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}
