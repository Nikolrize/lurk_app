import 'dart:ui';
import '../theme/app_colors.dart';
import '../../features/parties/screens/parties_screen.dart';
import 'package:flutter/material.dart';

import '../../features/home/screens/home_screen.dart';
import '../../features/find/screens/find_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  void _selectTab(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(onFindParties: () => _selectTab(1)),
          const FindSreen(),
          PartiesScreen(onQuickMatch: () => _selectTab(1)),
          const SafeArea(
            child: Center(child: Text('Your messages will appear here')),
          ),
          const SafeArea(
            child: Center(child: Text('Your profile will appear here')),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),

            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.text.withValues(alpha: 0.07),
                      AppColors.surface.withValues(alpha: 0.18),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.text.withValues(alpha: 0.18),
                  ),
                ),
                child: NavigationBar(
                  elevation: 0,
                  surfaceTintColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  indicatorColor: AppColors.primary.withValues(alpha: 0.55),
                  height: 76,
                  animationDuration: const Duration(milliseconds: 250),
                  backgroundColor: Colors.transparent,
                  indicatorShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectTab,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.search_outlined),
                      selectedIcon: Icon(Icons.search),
                      label: 'Find',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.groups_outlined),
                      selectedIcon: Icon(Icons.groups),
                      label: 'Parties',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.chat_bubble_outline),
                      selectedIcon: Icon(Icons.chat_bubble),
                      label: 'Messages',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: 'Profile',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
