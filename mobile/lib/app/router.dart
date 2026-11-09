import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/toungular_theme.dart';
import '../features/auth/auth_screen.dart';
import '../features/auth/account_screen.dart';
import '../features/auth/onboarding_screen.dart';
import '../features/auth/session_controller.dart';
import '../features/coach/coach_conversation_screen.dart';
import '../features/coach/coach_scenarios_screen.dart';
import '../features/courses/courses_screen.dart';
import '../features/courses/lesson_screen.dart';
import '../features/home/home_screen.dart';
import '../features/ielts/ielts_repository.dart';
import '../features/ielts/ielts_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/monetization/plus_screen.dart';
import '../features/placement/placement_screen.dart';
import '../features/speaking/speaking_history_screen.dart';
import '../features/speaking/speaking_screen.dart';
import '../features/vocabulary/vocabulary_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(path: '/', builder: (context, state) => const AppEntryScreen()),
    GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
    GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
    GoRoute(path: '/account', builder: (context, state) => const AccountScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/courses', builder: (context, state) => const CoursesScreen()),
    GoRoute(
      path: '/lessons/:lessonId',
      builder: (context, state) => LessonScreen(lessonId: state.pathParameters['lessonId']!),
    ),
    GoRoute(path: '/vocabulary', builder: (context, state) => const VocabularyScreen()),
    GoRoute(
      path: '/speaking',
      builder: (context, state) => SpeakingScreen(
        prompt: state.uri.queryParameters['prompt'],
        type: state.uri.queryParameters['type'] ?? 'prompt',
      ),
    ),
    GoRoute(path: '/speaking/history', builder: (context, state) => const SpeakingHistoryScreen()),
    GoRoute(path: '/coach', builder: (context, state) => const CoachScenariosScreen()),
    GoRoute(
      path: '/coach/:conversationId',
      builder: (context, state) => CoachConversationScreen(conversationId: state.pathParameters['conversationId']!),
    ),
    GoRoute(path: '/ielts', builder: (context, state) => const IeltsScreen()),
    GoRoute(
      path: '/ielts/response',
      builder: (context, state) {
        final args = state.extra! as IeltsResponseArgs;
        return SpeakingScreen(
          prompt: args.section.prompt,
          type: 'ielts',
          maxDurationSeconds: args.section.responseSeconds,
          ieltsAttemptId: args.attemptId,
          ieltsSectionId: args.section.id,
        );
      },
    ),
    GoRoute(path: '/progress', builder: (context, state) => const ProgressScreen()),
    GoRoute(path: '/plus', builder: (context, state) => const ToungularPlusScreen()),
    GoRoute(path: '/placement', builder: (context, state) => const PlacementScreen()),
  ],
);

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
    return const HomeScreen();
  }
}

