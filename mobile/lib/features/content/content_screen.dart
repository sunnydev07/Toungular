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
import '../vocabulary/vocabulary_repository.dart';
import 'content_repository.dart';

class ContentScreen extends ConsumerStatefulWidget {
  const ContentScreen({this.initialArticleId, super.key});
  final String? initialArticleId;

  @override
  ConsumerState<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends ConsumerState<ContentScreen> {
  final _player = AudioPlayer();
  final _recorder = AudioRecorder();
  final _outputController = TextEditingController();

  String _selectedLevel = 'All';
  late Future<List<ContentArticle>> _articlesFuture;
  ContentArticle? _selectedArticle;

  bool _audioPlaying = false;
  String? _audioPath;

  bool _recording = false;
  bool _transcribing = false;
  Duration _recordDuration = Duration.zero;
  Timer? _timer;
  String? _recordingPath;

  final Map<String, int> _selectedAnswers = <String, int>{};
  bool _evaluating = false;
  ArticleEvaluationResult? _evaluation;
  String? _error;

  final Set<String> _savedWords = <String>{};

  @override
  void initState() {
    super.initState();
    _loadArticles();
    if (widget.initialArticleId != null) {
      _loadSpecificArticle(widget.initialArticleId!);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_recording) unawaited(_recorder.cancel());
    _player.dispose();
    _recorder.dispose();
    _outputController.dispose();
    ref.read(voiceActivityProvider.notifier).setActive(false);
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

  void _loadArticles() {
    setState(() {
      _articlesFuture = ref
          .read(contentRepositoryProvider)
          .loadArticles(level: _selectedLevel);
    });
  }

  Future<void> _loadSpecificArticle(String id) async {
    try {
      final article = await ref.read(contentRepositoryProvider).loadArticle(id);
      if (mounted) setState(() => _selectedArticle = article);
    } catch (_) {
      // Keep articles list view
    }
  }

  Future<void> _toggleAudio(String text) async {
    if (_audioPlaying) {
      await _player.stop();
      if (mounted) setState(() => _audioPlaying = false);
      return;
    }

    try {
      setState(() => _error = null);
      if (_audioPath == null || !await File(_audioPath!).exists()) {
        final path = await ref
            .read(voiceRepositoryProvider)
            .synthesizeToFile(text);
        _audioPath = path;
      }
      await _player.setFilePath(_audioPath!);
      if (mounted) setState(() => _audioPlaying = true);
      await _player.play();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not generate speech audio.');
    } finally {
      if (mounted) setState(() => _audioPlaying = false);
    }
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      final path = await _recorder.stop();
      _recordingPath = null;
      _timer?.cancel();
      ref.read(voiceActivityProvider.notifier).setActive(false);
      setState(() {
        _recording = false;
        _recordDuration = Duration.zero;
        _transcribing = true;
      });

      if (path != null) {
        try {
          final text = await ref
              .read(voiceRepositoryProvider)
              .transcribe(File(path));
          if (mounted && text.isNotEmpty) {
            _outputController.text = text;
          }
        } catch (_) {
          if (mounted) {
            setState(
              () => _error = 'Transcription failed. Please type your response.',
            );
          }
        } finally {
          try {
            final file = File(path);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (_) {}
          if (mounted) setState(() => _transcribing = false);
        }
      } else {
        if (mounted) setState(() => _transcribing = false);
      }
    } else {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        setState(() => _error = 'Microphone permission is required.');
        return;
      }
      final path =
          '${Directory.systemTemp.path}${Platform.pathSeparator}toungular-input-${DateTime.now().millisecondsSinceEpoch}.m4a';
      _recordingPath = path;
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      ref.read(voiceActivityProvider.notifier).setActive(true);
      setState(() {
        _recording = true;
        _recordDuration = Duration.zero;
        _error = null;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _recordDuration += const Duration(seconds: 1));
        }
      });
    }
  }

  Future<void> _saveWordToSrs(ContentVocabulary vocab, String cefr) async {
    final mappedLevel = cefr == 'A1'
        ? 'beginner'
        : cefr == 'A2'
        ? 'elementary'
        : cefr == 'B1'
        ? 'intermediate'
        : cefr == 'B2'
        ? 'upperIntermediate'
        : 'advanced';

    try {
      await ref
          .read(vocabularyRepositoryProvider)
          .addWord(
            word: vocab.word,
            partOfSpeech: vocab.partOfSpeech,
            definition: vocab.definition,
            example: vocab.sampleSentence,
            level: mappedLevel,
          );
      if (mounted) {
        setState(() => _savedWords.add(vocab.word.toLowerCase()));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '“${vocab.word}” added to your Spaced Repetition (SRS) queue!',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save “${vocab.word}”. Please try again.'),
          ),
        );
      }
    }
  }

  void _showVocabularySheet(ContentVocabulary vocab, String cefr) {
    final isSaved = _savedWords.contains(vocab.word.toLowerCase());
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(ToungularSpace.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  vocab.word,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(width: ToungularSpace.s),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: ToungularColor.mist,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    vocab.partOfSpeech,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ToungularColor.leaf,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ToungularSpace.m),
            Text(
              vocab.definition,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: ToungularSpace.m),
            Container(
              padding: const EdgeInsets.all(ToungularSpace.m),
              decoration: BoxDecoration(
                color: ToungularColor.paper,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ToungularColor.sand),
              ),
              child: Text(
                '“${vocab.sampleSentence}”',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: ToungularSpace.l),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isSaved ? null : () => _saveWordToSrs(vocab, cefr),
                icon: Icon(isSaved ? Icons.check : Icons.school_outlined),
                label: Text(
                  isSaved
                      ? 'In SRS Flashcards'
                      : 'Add to Spaced Repetition (SRS)',
                ),
              ),
            ),
            const SizedBox(height: ToungularSpace.s),
          ],
        ),
      ),
    );
  }

  Future<void> _submitOutput() async {
    final text = _outputController.text.trim();
    final article = _selectedArticle;
    if (text.isEmpty || article == null) return;

    setState(() {
      _evaluating = true;
      _error = null;
    });

    try {
      final result = await ref
          .read(contentRepositoryProvider)
          .evaluateOutput(articleId: article.id, text: text);
      if (mounted) setState(() => _evaluation = result);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Evaluation could not be completed. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _evaluating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedArticle != null) {
      return _buildArticleReader(_selectedArticle!);
    }
    return _buildArticleCatalog();
  }

  Widget _buildArticleCatalog() => Scaffold(
    appBar: AppBar(
      title: const Text('Comprehensible input (i+1)'),
      actions: <Widget>[
        IconButton(
          tooltip: 'Comfort path',
          onPressed: () => context.push('/exposure'),
          icon: const Icon(Icons.shield_outlined),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ToungularSpace.l,
              ToungularSpace.s,
              ToungularSpace.l,
              ToungularSpace.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Calibrated reading',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: ToungularSpace.xs),
                Text(
                  'Krashen’s i+1 input calibrated to your proficiency level, paired with Swain’s output forcing.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: ToungularSpace.l,
              vertical: ToungularSpace.s,
            ),
            child: Row(
              children: <String>['All', 'A1', 'A2', 'B1', 'B2', 'C1', 'C2']
                  .map((level) {
                    final selected = _selectedLevel == level;
                    return Padding(
                      padding: const EdgeInsets.only(right: ToungularSpace.xs),
                      child: FilterChip(
                        label: Text(level),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => _selectedLevel = level);
                          _loadArticles();
                        },
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ContentArticle>>(
              future: _articlesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text('Could not load articles.'),
                        const SizedBox(height: ToungularSpace.s),
                        OutlinedButton(
                          onPressed: _loadArticles,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                final articles = snapshot.data ?? const <ContentArticle>[];
                if (articles.isEmpty) {
                  return const Center(
                    child: Text('No articles found for this level.'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(ToungularSpace.l),
                  itemCount: articles.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: ToungularSpace.m),
                  itemBuilder: (context, index) {
                    final article = articles[index];
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() {
                            _selectedArticle = article;
                            _audioPath = null;
                            _evaluation = null;
                            _selectedAnswers.clear();
                            _outputController.clear();
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(ToungularSpace.l),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ToungularColor.leaf,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      article.level,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: ToungularSpace.s),
                                  Text(
                                    article.topic,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium,
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${article.readingTimeMin} min read',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: ToungularSpace.s),
                              Text(
                                article.title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: ToungularSpace.xs),
                              Text(
                                article.summary,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: ToungularSpace.m),
                              Row(
                                children: <Widget>[
                                  Text(
                                    '${article.wordCount} words • ${article.vocabulary.length} key terms',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                  const Spacer(),
                                  const Icon(
                                    Icons.arrow_forward,
                                    size: 16,
                                    color: ToungularColor.leaf,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildArticleReader(ContentArticle article) => Scaffold(
    appBar: AppBar(
      title: Text(article.title),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => setState(() => _selectedArticle = null),
      ),
      actions: <Widget>[
        IconButton(
          tooltip: _audioPlaying ? 'Stop audio' : 'Listen to story',
          icon: Icon(_audioPlaying ? Icons.stop_circle : Icons.volume_up),
          onPressed: () => _toggleAudio(article.content),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(ToungularSpace.l),
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: ToungularColor.leaf,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                article.level,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: ToungularSpace.s),
            Text(
              article.topic,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              '${article.readingTimeMin} min read • ${article.wordCount} words',
            ),
          ],
        ),
        const SizedBox(height: ToungularSpace.m),
        Card(
          color: ToungularColor.paper,
          child: Padding(
            padding: const EdgeInsets.all(ToungularSpace.l),
            child: Text(
              article.content,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(height: 1.6),
            ),
          ),
        ),
        const SizedBox(height: ToungularSpace.l),
        Text(
          'Key target vocabulary',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: ToungularSpace.xs),
        const Text(
          'Tap any word to view details and save to Spaced Repetition (SRS).',
        ),
        const SizedBox(height: ToungularSpace.s),
        Wrap(
          spacing: ToungularSpace.s,
          runSpacing: ToungularSpace.xs,
          children: article.vocabulary
              .map((vocab) {
                final isSaved = _savedWords.contains(vocab.word.toLowerCase());
                return ActionChip(
                  avatar: Icon(
                    isSaved ? Icons.check_circle : Icons.bookmark_border,
                    size: 16,
                    color: ToungularColor.leaf,
                  ),
                  label: Text(vocab.word),
                  onPressed: () => _showVocabularySheet(vocab, article.level),
                );
              })
              .toList(growable: false),
        ),
        const SizedBox(height: ToungularSpace.xl),
        Text(
          'Comprehension check',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: ToungularSpace.s),
        for (int i = 0; i < article.questions.length; i++) ...<Widget>[
          _buildQuestionCard(article.questions[i], i + 1),
          const SizedBox(height: ToungularSpace.m),
        ],
        const SizedBox(height: ToungularSpace.l),
        Text(
          'Output-forcing practice (Swain)',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: ToungularSpace.xs),
        Text(article.outputPrompt.instruction),
        const SizedBox(height: ToungularSpace.s),
        Card(
          color: ToungularColor.mist,
          child: Padding(
            padding: const EdgeInsets.all(ToungularSpace.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Recommended target words: ${article.outputPrompt.recommendedTargetWords.join(", ")}',
                ),
                const SizedBox(height: ToungularSpace.xs),
                Text(
                  'Minimum length: ${article.outputPrompt.requiredWordCount} words',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: ToungularSpace.m),
        if (_recording)
          Container(
            margin: const EdgeInsets.only(bottom: ToungularSpace.s),
            padding: const EdgeInsets.symmetric(
              horizontal: ToungularSpace.m,
              vertical: ToungularSpace.s,
            ),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.fiber_manual_record,
                  color: Colors.red,
                  size: 16,
                ),
                const SizedBox(width: ToungularSpace.s),
                Text(
                  'Listening… ${_recordDuration.inSeconds}s (Tap mic to stop)',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        if (_transcribing)
          const Padding(
            padding: EdgeInsets.only(bottom: ToungularSpace.s),
            child: Center(child: Text('Transcribing speech…')),
          ),
        TextField(
          controller: _outputController,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: 'Type or dictate your response here…',
            suffixIcon: IconButton(
              onPressed: _evaluating || _transcribing ? null : _toggleRecording,
              icon: Icon(
                _recording ? Icons.stop : Icons.mic,
                color: _recording ? Colors.red : ToungularColor.leaf,
              ),
            ),
          ),
        ),
        const SizedBox(height: ToungularSpace.m),
        FilledButton.icon(
          onPressed: _evaluating || _recording ? null : _submitOutput,
          icon: const Icon(Icons.send),
          label: Text(
            _evaluating ? 'Analyzing syntax…' : 'Evaluate my response',
          ),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: ToungularSpace.s),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (_evaluation != null) ...<Widget>[
          const SizedBox(height: ToungularSpace.l),
          _buildEvaluationScorecard(_evaluation!),
        ],
        const SizedBox(height: ToungularSpace.xl),
      ],
    ),
  );

  Widget _buildQuestionCard(ContentQuestion q, int index) {
    final selected = _selectedAnswers[q.id];
    final answered = selected != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ToungularSpace.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '$index. ${q.question}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: ToungularSpace.s),
            for (int i = 0; i < q.options.length; i++) ...<Widget>[
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: answered
                    ? null
                    : () => setState(() => _selectedAnswers[q.id] = i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 8,
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        selected == i
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 20,
                        color: selected == i
                            ? ToungularColor.leaf
                            : Colors.grey,
                      ),
                      const SizedBox(width: ToungularSpace.s),
                      Expanded(child: Text(q.options[i])),
                    ],
                  ),
                ),
              ),
            ],
            if (answered) ...<Widget>[
              const Divider(),
              Row(
                children: <Widget>[
                  Icon(
                    selected == q.correctIndex
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: selected == q.correctIndex
                        ? ToungularColor.leaf
                        : Colors.red,
                  ),
                  const SizedBox(width: ToungularSpace.s),
                  Expanded(
                    child: Text(
                      selected == q.correctIndex
                          ? 'Correct! ${q.explanation}'
                          : 'Incorrect. ${q.explanation}',
                      style: TextStyle(
                        color: selected == q.correctIndex
                            ? ToungularColor.leaf
                            : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEvaluationScorecard(ArticleEvaluationResult eval) => Card(
    color: ToungularColor.lime.withValues(alpha: 0.25),
    child: Padding(
      padding: const EdgeInsets.all(ToungularSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 24,
                backgroundColor: ToungularColor.leaf,
                child: Text(
                  '${eval.overallScore}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: ToungularSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Output feedback',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      'Vocabulary: ${eval.vocabularyScore}% • Mechanics: ${eval.mechanicsScore}%',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ToungularSpace.m),
          Text(
            'Target words used (${eval.targetWordsUsed.length}):',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: ToungularSpace.xs),
          Wrap(
            spacing: 6,
            children: eval.targetWordsUsed
                .map((w) => Chip(label: Text(w), backgroundColor: Colors.white))
                .toList(),
          ),
          if (eval.strengths.isNotEmpty) ...<Widget>[
            const SizedBox(height: ToungularSpace.s),
            for (final strength in eval.strengths)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.check, size: 16, color: ToungularColor.leaf),
                  const SizedBox(width: ToungularSpace.xs),
                  Expanded(child: Text(strength)),
                ],
              ),
          ],
          if (eval.suggestions.isNotEmpty) ...<Widget>[
            const SizedBox(height: ToungularSpace.s),
            for (final suggestion in eval.suggestions)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: ToungularColor.coral,
                  ),
                  const SizedBox(width: ToungularSpace.xs),
                  Expanded(child: Text(suggestion)),
                ],
              ),
          ],
          if ((eval.recast ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: ToungularSpace.m),
            Container(
              padding: const EdgeInsets.all(ToungularSpace.m),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Recast (model rewrite):',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: ToungularColor.leaf,
                    ),
                  ),
                  const SizedBox(height: ToungularSpace.xs),
                  Text(
                    eval.recast!,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
