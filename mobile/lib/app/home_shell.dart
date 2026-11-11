import 'package:flutter/material.dart';

import '../features/courses/courses_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/practice/practice_screen.dart';
import '../features/today/today_screen.dart';

// shortcut: tab state is local, not URL-addressable; upgrade to StatefulShellRoute when per-tab deep links matter.

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  // Tabs build on first visit so Progress does not fetch on app start.
  final Set<int> _visited = <int>{0};

  void _openTab(int index) {
    if (index == _index) return;
    setState(() {
      _index = index;
      _visited.add(index);
    });
  }

  Widget _buildTab(int index) => switch (index) {
    1 => const CoursesScreen(),
    2 => const PracticeScreen(),
    3 => const ProgressScreen(),
    _ => TodayScreen(onOpenPractice: () => _openTab(2)),
  };

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _openTab(0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: List<Widget>.generate(
            4,
            (index) => _visited.contains(index)
                ? _buildTab(index)
                : const SizedBox.shrink(),
            growable: false,
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _openTab,
          destinations: const <NavigationDestination>[
            NavigationDestination(
              selectedIcon: Icon(Icons.today),
              icon: Icon(Icons.today_outlined),
              label: 'Today',
            ),
            NavigationDestination(
              selectedIcon: Icon(Icons.school),
              icon: Icon(Icons.school_outlined),
              label: 'Learn',
            ),
            NavigationDestination(
              selectedIcon: Icon(Icons.record_voice_over),
              icon: Icon(Icons.record_voice_over_outlined),
              label: 'Practice',
            ),
            NavigationDestination(
              selectedIcon: Icon(Icons.insights),
              icon: Icon(Icons.insights_outlined),
              label: 'Progress',
            ),
          ],
        ),
      ),
    );
  }
}
