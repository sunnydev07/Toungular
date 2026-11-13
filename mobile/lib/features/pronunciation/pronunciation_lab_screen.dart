import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';

import '../../core/network/api_client.dart';
import '../../core/state/voice_activity_controller.dart';
import '../../core/theme/toungular_theme.dart';
import '../../core/voice/voice_repository.dart';
import '../../shared/models/learning_models.dart';
import 'pronunciation_repository.dart';

class PronunciationLabScreen extends ConsumerStatefulWidget {
  const PronunciationLabScreen({super.key, this.initialPairId});

  final String? initialPairId;

  @override
  ConsumerState<PronunciationLabScreen> createState() =>
      _PronunciationLabScreenState();
}

class _PronunciationLabScreenState
    extends ConsumerState<PronunciationLabScreen> {
  final _recorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  final _manualTranscriptController = TextEditingController();

  List<MinimalPairSet> _pairs = <MinimalPairSet>[];
  MinimalPairSet? _selectedPair;
  String _targetChoice = 'A'; // 'A' or 'B'
  bool _loading = true;
  bool _recording = false;
  bool _evaluating = false;
  bool _playingAudio = false;
  bool _sttAvailable = false;
  String? _recordingPath;
  String? _error;
  PhonemeAnalysisResult? _analysisResult;

  @override
  void initState() {
    super.initState();
    _loadPairs();
  }

  @override
  void dispose() {
    if (_recording) unawaited(_recorder.cancel());
    ref.read(voiceActivityProvider.notifier).setActive(false);
    unawaited(_recorder.dispose());
    unawaited(_audioPlayer.dispose());
    _manualTranscriptController.dispose();
    final path = _recordingPath;
    if (path != null) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _loadPairs() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repository = ref.read(pronunciationRepositoryProvider);
      final pairs = await repository.loadPairs();
      final status = await ref.read(voiceRepositoryProvider).status();

      if (!mounted) return;
      setState(() {
        _pairs = pairs;
        _sttAvailable = status.sttAvailable;
        if (pairs.isNotEmpty) {
          _selectedPair = pairs.firstWhere(
            (p) => p.id == widget.initialPairId,
            orElse: () => pairs.first,
          );
        }
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
        _error = 'Failed to load minimal pairs. Check connection.';
      });
    }
  }

  Future<void> _playSample(String text) async {
    if (_playingAudio) {
      await _audioPlayer.stop();
      setState(() => _playingAudio = false);
      return;
    }
    setState(() => _playingAudio = true);

    try {
      final filePath = await ref
          .read(voiceRepositoryProvider)
          .synthesizeToFile(text);
      await _audioPlayer.setFilePath(filePath);
      await _audioPlayer.play();
    } catch (_) {
      // Audio synthesis fallback
    } finally {
      if (mounted) setState(() => _playingAudio = false);
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        if (_recordingPath != null) {
          try {
            final oldFile = File(_recordingPath!);
            if (await oldFile.exists()) {
              await oldFile.delete();
            }
          } catch (_) {}
        }
        final path =
            '${Directory.systemTemp.path}${Platform.pathSeparator}phoneme_drill_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: path,
        );
        ref.read(voiceActivityProvider.notifier).setActive(true);
        setState(() {
          _recording = true;
          _recordingPath = path;
          _error = null;
          _analysisResult = null;
        });
      }
    } catch (e) {
      setState(() => _error = 'Unable to access microphone: $e');
    }
  }

  Future<void> _stopAndAnalyze() async {
    if (!_recording || _selectedPair == null) return;

    setState(() {
      _recording = false;
      _evaluating = true;
    });

    try {
      await _recorder.stop();
      String transcript = _manualTranscriptController.text.trim();

      if (_sttAvailable && _recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          final transcribed = await ref
              .read(voiceRepositoryProvider)
              .transcribe(file);
          if (transcribed.isNotEmpty) {
            transcript = transcribed;
            _manualTranscriptController.text = transcript;
          }
        }
      }

      // Never grade the target word back to the learner: an empty transcript
      // means there is nothing to assess.
      if (transcript.isEmpty) {
        if (mounted) {
          setState(() {
            _evaluating = false;
            _error = _sttAvailable
                ? 'No speech was detected. Speak clearly or type what you said to evaluate.'
                : 'Speech recognition is not configured. Type the word you spoke to evaluate.';
          });
        }
        return;
      }

      final repository = ref.read(pronunciationRepositoryProvider);
      final result = await repository.analyzeAttempt(
        pairId: _selectedPair!.id,
        targetChoice: _targetChoice,
        transcript: transcript,
      );

      if (!mounted) return;
      setState(() {
        _analysisResult = result;
        _evaluating = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _evaluating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Evaluation error: $e';
        _evaluating = false;
      });
    } finally {
      ref.read(voiceActivityProvider.notifier).setActive(false);
      final path = _recordingPath;
      if (path != null) {
        _recordingPath = null;
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _analyzeManualText() async {
    if (_selectedPair == null) return;
    final text = _manualTranscriptController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Enter or speak the target word to analyze.');
      return;
    }

    setState(() {
      _evaluating = true;
      _error = null;
    });

    try {
      final repository = ref.read(pronunciationRepositoryProvider);
      final result = await repository.analyzeAttempt(
        pairId: _selectedPair!.id,
        targetChoice: _targetChoice,
        transcript: text,
      );

      if (!mounted) return;
      setState(() {
        _analysisResult = result;
        _evaluating = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _evaluating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Evaluation error: $e';
        _evaluating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Phoneme Lab')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_pairs.isEmpty || _selectedPair == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Phoneme Lab')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'No minimal pairs available.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _loadPairs, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final pair = _selectedPair!;
    final isWordA = _targetChoice == 'A';
    final targetWord = isWordA ? pair.wordA : pair.wordB;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phoneme Lab'),
        actions: [
          IconButton(
            tooltip: 'View Mastery Profile',
            icon: const Icon(Icons.workspace_premium_outlined),
            onPressed: () => context.push('/mastery'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Contrasting Phoneme Selector Carousel
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _pairs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final p = _pairs[index];
                final isSelected = p.id == pair.id;
                return ChoiceChip(
                  label: Text(
                    p.phoneticContrast,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected ? Colors.white : ToungularColor.ink,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: ToungularColor.leaf,
                  backgroundColor: ToungularColor.sand.withValues(alpha: 0.5),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedPair = p;
                        _analysisResult = null;
                        _manualTranscriptController.clear();
                      });
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Header Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: ToungularColor.mist,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          pair.level,
                          style: const TextStyle(
                            color: ToungularColor.leaf,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        pair.category.toUpperCase(),
                        style: const TextStyle(
                          color: ToungularColor.mutedInk,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.volume_up_outlined,
                        color: ToungularColor.leaf,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pair.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Distinguish the subtle acoustic contrast: ${pair.phoneticContrast}',
                    style: const TextStyle(color: ToungularColor.mutedInk),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Minimal Pair Comparison Cards (Interactive Target Choice)
          Row(
            children: [
              Expanded(
                child: _buildWordCard(
                  wordItem: pair.wordA,
                  choiceLabel: 'Word A',
                  choiceKey: 'A',
                  isSelected: isWordA,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildWordCard(
                  wordItem: pair.wordB,
                  choiceLabel: 'Word B',
                  choiceKey: 'B',
                  isSelected: !isWordA,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Articulatory Mechanics Guide
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.psychology_outlined,
                        color: ToungularColor.leaf,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Articulatory Biomechanics',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  _buildArticulatoryRow(
                    icon: Icons.record_voice_over_outlined,
                    label: 'Tongue Placement',
                    detail: pair.articulatoryGuide.tonguePlacement,
                  ),
                  const SizedBox(height: 10),
                  _buildArticulatoryRow(
                    icon: Icons.face_retouching_natural,
                    label: 'Lip Shape',
                    detail: pair.articulatoryGuide.lipShape,
                  ),
                  const SizedBox(height: 10),
                  _buildArticulatoryRow(
                    icon: Icons.waves,
                    label: 'Voicing',
                    detail: pair.articulatoryGuide.voicing,
                  ),
                  const SizedBox(height: 10),
                  _buildArticulatoryRow(
                    icon: Icons.warning_amber_rounded,
                    label: 'Common Pitfall',
                    detail: pair.articulatoryGuide.commonPitfall,
                    isWarning: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Contextual Sentence Drill
          Card(
            color: ToungularColor.mist.withValues(alpha: 0.6),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.menu_book_outlined,
                        color: ToungularColor.leaf,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Sentence Drill',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.volume_up,
                          size: 20,
                          color: ToungularColor.leaf,
                        ),
                        tooltip: 'Listen to sentence drill',
                        onPressed: () => _playSample(pair.sentenceDrill),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '"${pair.sentenceDrill}"',
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 15,
                      color: ToungularColor.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Recording / Practice Drill Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Practice Target: "${targetWord.word}" (${targetWord.ipa})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Speak or verify the word into the microphone to measure phonetic clarity and earn Acoustic XP.',
                    style: TextStyle(
                      color: ToungularColor.mutedInk,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _manualTranscriptController,
                    decoration: InputDecoration(
                      labelText: 'Spoken word or phrase',
                      hintText: targetWord.word,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send),
                        tooltip: 'Evaluate transcript',
                        onPressed: _evaluating ? null : _analyzeManualText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Center(
                    child: Column(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _recording
                                ? ToungularColor.coral
                                : ToungularColor.leaf,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          icon: Icon(_recording ? Icons.stop : Icons.mic),
                          label: Text(
                            _recording ? 'Stop & Verify' : 'Record Target Word',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: _evaluating
                              ? null
                              : (_recording
                                    ? _stopAndAnalyze
                                    : _startRecording),
                        ),
                        if (_recording) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Listening... Speak clearly.',
                            style: TextStyle(
                              color: ToungularColor.coral,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  if (_evaluating) ...[
                    const SizedBox(height: 16),
                    const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text(
                            'Analyzing phonetic acoustic contours...',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Acoustic Feedback Card (when analysis exists)
          if (_analysisResult != null) _buildAnalysisCard(_analysisResult!),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildWordCard({
    required PhonemeItem wordItem,
    required String choiceLabel,
    required String choiceKey,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _targetChoice = choiceKey;
          _manualTranscriptController.clear();
          _analysisResult = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? ToungularColor.lime.withValues(alpha: 0.25)
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? ToungularColor.leaf : ToungularColor.sand,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  choiceLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? ToungularColor.leaf
                        : ToungularColor.mutedInk,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: ToungularColor.leaf,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              wordItem.word,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: ToungularColor.ink,
              ),
            ),
            Text(
              wordItem.ipa,
              style: const TextStyle(
                fontSize: 14,
                color: ToungularColor.leaf,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              wordItem.meaning,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: ToungularColor.mutedInk,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _playSample(wordItem.audioSampleText),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.volume_up, size: 16, color: ToungularColor.leaf),
                  SizedBox(width: 4),
                  Text(
                    'Listen',
                    style: TextStyle(
                      fontSize: 12,
                      color: ToungularColor.leaf,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticulatoryRow({
    required IconData icon,
    required String label,
    required String detail,
    bool isWarning = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: isWarning ? ToungularColor.coral : ToungularColor.leaf,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isWarning ? ToungularColor.coral : ToungularColor.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: const TextStyle(
                  fontSize: 13,
                  color: ToungularColor.mutedInk,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisCard(PhonemeAnalysisResult result) {
    final isAccurate = result.isAccurate;
    final isConfused = result.confusedWithCounterpart;

    return Card(
      color: isAccurate
          ? ToungularColor.mist
          : (isConfused ? const Color(0xFFFFF4ED) : Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isAccurate
              ? ToungularColor.leaf
              : (isConfused ? ToungularColor.coral : ToungularColor.sand),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isAccurate
                      ? ToungularColor.leaf
                      : ToungularColor.coral,
                  radius: 20,
                  child: Icon(
                    isAccurate ? Icons.check : Icons.priority_high,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAccurate
                          ? 'Target Phoneme Achieved!'
                          : (isConfused
                                ? 'Phoneme Confusion Detected'
                                : 'Needs Polish'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Accuracy: ${result.accuracyScore.toInt()}%',
                      style: TextStyle(
                        fontSize: 13,
                        color: isAccurate
                            ? ToungularColor.leaf
                            : ToungularColor.coral,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: ToungularColor.lime,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '+${result.awardedXp} Acoustic XP',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: ToungularColor.ink,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Text(
              result.phonemeFeedback,
              style: const TextStyle(
                fontSize: 14,
                color: ToungularColor.ink,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ToungularColor.sand),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    size: 18,
                    color: ToungularColor.leaf,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Biomechanics Tip: ${result.articulatoryTip}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: ToungularColor.mutedInk,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
