import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/util/l10n_ext.dart';
import '../app/theme/tokens.dart';
import '../features/editor/presentation/editor_screen.dart';
import '../features/folders/presentation/folders_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/settings/data/settings_repository.dart';
import '../features/settings/presentation/settings_screen.dart';

String initialLocationFor(LandingScreen l) => switch (l) {
  LandingScreen.home => '/home',
  LandingScreen.search => '/search',
  LandingScreen.folders => '/folders',
};

GoRouter buildRouter({String initialLocation = '/home'}) {
  final rootKey = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/folders',
                builder: (_, _) => const FoldersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, _) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/note/:id',
        parentNavigatorKey: rootKey,
        builder: (_, s) => EditorScreen(noteId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/folder/:id',
        parentNavigatorKey: rootKey,
        builder: (_, s) =>
            FolderDetailScreen(folderId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/tag/:id',
        parentNavigatorKey: rootKey,
        builder: (_, s) => TagDetailScreen(tagId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/library/:scope',
        parentNavigatorKey: rootKey,
        builder: (_, s) => LibraryScreen(scope: s.pathParameters['scope']!),
      ),
    ],
  );
}

/// Bottom navigation on phones, a navigation rail on wider screens.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = [
      (Icons.home_outlined, Icons.home, l10n.navHome),
      (Icons.search, Icons.search, l10n.navSearch),
      (Icons.folder_outlined, Icons.folder, l10n.navFolders),
      (Icons.settings_outlined, Icons.settings, l10n.navSettings),
    ];
    void select(int i) =>
        shell.goBranch(i, initialLocation: i == shell.currentIndex);
    final wide = MediaQuery.sizeOf(context).width >= Sizes.railBreakpoint;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: select,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final i in items)
                  NavigationRailDestination(
                    icon: Icon(i.$1),
                    selectedIcon: Icon(i.$2),
                    label: Text(i.$3),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: shell),
          ],
        ),
      );
    }
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: select,
        destinations: [
          for (final i in items)
            NavigationDestination(
              icon: Icon(i.$1),
              selectedIcon: Icon(i.$2),
              label: i.$3,
            ),
        ],
      ),
    );
  }
}
