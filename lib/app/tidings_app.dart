import 'package:flutter/material.dart';

import '../screens/home_screen.dart';
import '../screens/onboarding_screen.dart';
import '../state/app_state.dart';
import '../state/tidings_settings.dart';
import '../theme/account_accent.dart';
import '../theme/tidings_theme.dart';

class TidingsApp extends StatefulWidget {
  const TidingsApp({super.key});

  @override
  State<TidingsApp> createState() => _TidingsAppState();
}

class _TidingsAppState extends State<TidingsApp> {
  late final TidingsSettings _settings = TidingsSettings();
  late final AppState _appState = AppState();

  @override
  void dispose() {
    _settings.dispose();
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TidingsSettingsScope(
      settings: _settings,
      child: AnimatedBuilder(
        animation: Listenable.merge([_settings, _appState]),
        builder: (context, _) {
          final account = _appState.selectedAccount;
          final accent = account == null
              ? TidingsTheme.defaultAccent
              : accentFromAccount(account.id);
          return MaterialApp(
            title: 'Tidings',
            debugShowCheckedModeBanner: false,
            themeMode: _settings.themeMode,
            theme: TidingsTheme.lightTheme(
              accentColor: accent,
              paletteSource: _settings.paletteSource,
              cornerRadiusScale: _settings.cornerRadiusScale,
              fontScale: 1.0,
            ),
            darkTheme: TidingsTheme.darkTheme(
              accentColor: accent,
              paletteSource: _settings.paletteSource,
              cornerRadiusScale: _settings.cornerRadiusScale,
              fontScale: 1.0,
            ),
            home: _appState.hasAccounts
                ? HomeScreen(
                    appState: _appState,
                    accent: accent,
                  )
                : OnboardingScreen(
                    appState: _appState,
                    accent: accent,
                  ),
          );
        },
      ),
    );
  }
}
