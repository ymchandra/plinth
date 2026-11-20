import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/settings/data/settings_repository.dart';
import '../l10n/app_localizations.dart';
import 'providers.dart';
import 'router.dart';
import 'theme/theme.dart';

class PlinthApp extends ConsumerStatefulWidget {
  const PlinthApp({super.key});

  @override
  ConsumerState<PlinthApp> createState() => _PlinthAppState();
}

class _PlinthAppState extends ConsumerState<PlinthApp> {
  late final GoRouter _router = buildRouter(
    initialLocation: initialLocationFor(
      ref.read(initialSettingsProvider).landing,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final pref = ref.watch(settingsProvider.select((s) => s.theme));
    return MaterialApp.router(
      onGenerateTitle: (c) => AppLocalizations.of(c).appName,
      routerConfig: _router,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: switch (pref) {
        ThemePreference.system => ThemeMode.system,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
      },
      localizationsDelegates: const [
        AppLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}

/// Shown instead of the app when the database cannot be opened.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    l10n.startupErrorTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.startupErrorBody('$error'),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
