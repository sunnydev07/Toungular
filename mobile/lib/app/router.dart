import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_screen.dart';
import '../features/auth/account_screen.dart';
import '../features/auth/onboarding_screen.dart';
import '../features/auth/session_controller.dart';
import '../features/coach/coach_conversation_screen.dart';
import '../features/coach/coach_scenarios_screen.dart';
import '../features/content/content_screen.dart';
import '../features/courses/courses_screen.dart';
import '../features/courses/lesson_screen.dart';
import '../features/exposure/exposure_screen.dart';
import '../features/ielts/ielts_repository.dart';
import '../features/ielts/ielts_screen.dart';
import '../features/mastery/mastery_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/monetization/plus_screen.dart';
import '../features/placement/placement_screen.dart';
import '../features/pronunciation/pronunciation_lab_screen.dart';
import '../features/shadow/shadow_screen.dart';
import '../features/speaking/speaking_history_screen.dart';
import '../features/speaking/speaking_screen.dart';
import '../features/vocabulary/vocabulary_screen.dart';

import 'home_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // The redirect only reruns on navigation, so sign-in and sign-out must
  // invalidate it; otherwise a rejected session leaves the user on a dead tab.
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen<SessionState>(sessionControllerProvider, (_, __) {
    refresh.value += 1;
  });

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final container = ProviderScope.containerOf(context, listen: false);
      final session = container.read(sessionControllerProvider);
      if (session.isLoading) return null;
      final path = state.matchedLocation;
      final isAuthRoute = path == '/auth' || path == '/';
      final isOnboardingRoute = path == '/onboarding';

      if (!session.isSignedIn) {
        return isAuthRoute ? null : '/auth';
      }
      if (session.requiresOnboarding) {
        return isOnboardingRoute ? null : '/onboarding';
      }
      if (path == '/auth') {
        return '/home';
      }
      return null;
    },
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Page not found')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text('The requested page could not be found.'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('Back to Home'),
          ),
        ],
      ),
    ),
  ),
  routes: <RouteBase>[
    GoRoute(path: '/', builder: (context, state) => const AppEntryScreen()),
    GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/account',
      builder: (context, state) => const AccountScreen(),
    ),
    GoRoute(path: '/home', builder: (context, state) => const HomeShell()),
    GoRoute(
      path: '/courses',
      builder: (context, state) => const CoursesScreen(),
    ),
    GoRoute(
      path: '/lessons/:lessonId',
      builder: (context, state) =>
          LessonScreen(lessonId: state.pathParameters['lessonId']!),
    ),
    GoRoute(
      path: '/vocabulary',
      builder: (context, state) => const VocabularyScreen(),
    ),
    GoRoute(
      path: '/exposure',
      builder: (context, state) => const ExposureScreen(),
    ),
    GoRoute(
      path: '/speaking',
      builder: (context, state) => SpeakingScreen(
        prompt: state.uri.queryParameters['prompt'],
        type: state.uri.queryParameters['type'] ?? 'prompt',
      ),
    ),
    GoRoute(
      path: '/speaking/history',
      builder: (context, state) => const SpeakingHistoryScreen(),
    ),
    GoRoute(
      path: '/coach',
      builder: (context, state) => const CoachScenariosScreen(),
    ),
    GoRoute(
      path: '/coach/:conversationId',
      builder: (context, state) => CoachConversationScreen(
        conversationId: state.pathParameters['conversationId']!,
      ),
    ),
    GoRoute(path: '/ielts', builder: (context, state) => const IeltsScreen()),
    GoRoute(
      path: '/ielts/response',
      builder: (context, state) {
        final extra = state.extra;
        if (extra is! IeltsResponseArgs) {
          return Scaffold(
            appBar: AppBar(title: const Text('IELTS Practice')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Missing IELTS response details.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go('/ielts'),
                    child: const Text('Go to IELTS'),
                  ),
                ],
              ),
            ),
          );
        }
        return SpeakingScreen(
          prompt: extra.section.prompt,
          type: 'ielts',
          maxDurationSeconds: extra.section.responseSeconds,
          ieltsAttemptId: extra.attemptId,
          ieltsSectionId: extra.section.id,
        );
      },
    ),
    GoRoute(
      path: '/progress',
      builder: (context, state) => const ProgressScreen(),
    ),
    GoRoute(
      path: '/plus',
      builder: (context, state) => const ToungularPlusScreen(),
    ),
    GoRoute(
      path: '/placement',
      builder: (context, state) => const PlacementScreen(),
    ),
    GoRoute(path: '/shadow', builder: (context, state) => const ShadowScreen()),
    GoRoute(
      path: '/shadow/:passageId',
      builder: (context, state) =>
          ShadowScreen(passageId: state.pathParameters['passageId']),
    ),
    GoRoute(
      path: '/content',
      builder: (context, state) => const ContentScreen(),
    ),
    GoRoute(
      path: '/content/:articleId',
      builder: (context, state) =>
          ContentScreen(initialArticleId: state.pathParameters['articleId']),
    ),
    GoRoute(
      path: '/pronunciation',
      builder: (context, state) => const PronunciationLabScreen(),
    ),
    GoRoute(
      path: '/pronunciation/:pairId',
      builder: (context, state) =>
          PronunciationLabScreen(initialPairId: state.pathParameters['pairId']),
    ),
    GoRoute(
      path: '/mastery',
      builder: (context, state) => const MasteryScreen(),
    ),
    ],
  );
});

class AppEntryScreen extends ConsumerWidget {
  const AppEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    if (session.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!session.isSignedIn) return const AuthScreen();
    if (session.requiresOnboarding) return const OnboardingScreen();
    return const HomeShell();
  }
}
