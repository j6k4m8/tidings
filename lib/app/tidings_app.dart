import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../screens/home_screen.dart';
import '../screens/onboarding_screen.dart';
import '../state/app_state.dart';
import '../state/tidings_settings.dart';
import '../theme/account_accent.dart';
import '../theme/tidings_theme.dart';
import '../widgets/tidings_background.dart';

class TidingsApp extends StatefulWidget {
  const TidingsApp({super.key});

  @override
  State<TidingsApp> createState() => _TidingsAppState();
}

class _TidingsAppState extends State<TidingsApp> {
  late final TidingsSettings _settings = TidingsSettings();
  late final AppState _appState = AppState();
  late final Future<void> _initFuture = _appState.initialize();

  @override
  void initState() {
    super.initState();
    _settings.load();
  }

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
      child: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          return AnimatedBuilder(
            animation: Listenable.merge([_settings, _appState]),
            builder: (context, _) {
              final account = _appState.selectedAccount;
              final baseAccent = account == null
                  ? TidingsTheme.defaultAccent
                  : account.accentColorValue == null
                      ? accentFromAccount(account.id)
                      : Color(account.accentColorValue!);
              final brightness = _settings.themeMode == ThemeMode.system
                  ? WidgetsBinding.instance.platformDispatcher.platformBrightness
                  : (_settings.themeMode == ThemeMode.dark
                      ? Brightness.dark
                      : Brightness.light);
              final accent = resolveAccent(baseAccent, brightness);
              return MaterialApp(
                title: 'Tidings',
                debugShowCheckedModeBanner: false,
                localizationsDelegates: const [
                  FlutterQuillLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: FlutterQuillLocalizations.supportedLocales,
                themeMode: _settings.themeMode,
                theme: TidingsTheme.lightTheme(
                  accentColor: resolveAccent(baseAccent, Brightness.light),
                  paletteSource: _settings.paletteSource,
                  cornerRadiusScale: _settings.cornerRadiusScale,
                  fontScale: 1.0,
                ),
                darkTheme: TidingsTheme.darkTheme(
                  accentColor: resolveAccent(baseAccent, Brightness.dark),
                  paletteSource: _settings.paletteSource,
                  cornerRadiusScale: _settings.cornerRadiusScale,
                  fontScale: 1.0,
                ),
                home: snapshot.connectionState != ConnectionState.done
                    ? _BootSplash(accent: accent)
                    : _appState.hasAccounts
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
          );
        },
      ),
    );
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.titleMedium;
    return Scaffold(
      body: TidingsBackground(
        accent: accent,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    accent.withValues(alpha: 0.85),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Loading your mail…', style: textStyle),
            ],
          ),
        ),
      ),
    );
  }
}
