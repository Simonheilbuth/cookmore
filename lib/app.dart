import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_services.dart';
import 'models/profile.dart';
import 'services/sync_service.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/profile_select_screen.dart';
import 'ui/theme.dart';
import 'ui/widgets/state_views.dart';
import 'viewmodels/session_view_model.dart';
import 'viewmodels/timer_view_model.dart';

/// Root widget. Provides app-wide objects and decides which screen to show:
/// the profile picker, or the main app for the selected profile.
class CookMoreApp extends StatelessWidget {
  const CookMoreApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppServices>.value(value: services),
        ChangeNotifierProvider<SyncService>.value(value: services.sync),
        ChangeNotifierProvider(
          create: (_) => SessionViewModel(services.profiles)..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => TimerViewModel(services.notifications),
        ),
      ],
      child: Consumer<SessionViewModel>(
        builder: (context, session, _) {
          final profile = session.current;
          return MaterialApp(
            title: 'CookMore',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: _themeMode(profile?.themePreference),
            home: session.isLoading
                ? const Scaffold(body: LoadingView())
                : profile == null
                    ? const ProfileSelectScreen()
                    // A new key resets all screens when the profile changes.
                    : HomeShell(key: ValueKey(profile.id)),
          );
        },
      ),
    );
  }

  ThemeMode _themeMode(ThemePreference? preference) {
    switch (preference) {
      case ThemePreference.light:
        return ThemeMode.light;
      case ThemePreference.dark:
        return ThemeMode.dark;
      case ThemePreference.system:
      case null:
        return ThemeMode.system;
    }
  }
}
