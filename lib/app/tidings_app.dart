import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../screens/home_screen.dart';
import '../screens/onboarding_screen.dart';
import '../models/account_models.dart';
import '../state/app_state.dart';
import '../state/shortcut_definitions.dart';
import '../state/tidings_settings.dart';
import '../theme/account_accent.dart';
import '../theme/theme_palette.dart';
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

  List<PlatformMenuItem> _buildMenuBar() {
    final appMenuItems = <PlatformMenuItem>[];
    if (PlatformProvidedMenuItem.hasMenu(PlatformProvidedMenuItemType.about)) {
      appMenuItems.add(
        const PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.about),
      );
    }
    if (PlatformProvidedMenuItem.hasMenu(PlatformProvidedMenuItemType.quit)) {
      appMenuItems.add(
        const PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.quit),
      );
    }
    const editMenu = PlatformMenu(
      label: 'Edit',
      menus: [
        PlatformMenuItem(label: 'Undo'),
        PlatformMenuItem(label: 'Redo'),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(label: 'Cut'),
            PlatformMenuItem(label: 'Copy'),
            PlatformMenuItem(label: 'Paste'),
            PlatformMenuItem(label: 'Select All'),
          ],
        ),
      ],
    );
    final canInvoke = _appState.hasMenuActionHandler;
    final hasSelection = _appState.menuHasThreadSelection;
    final isUnread = _appState.menuThreadUnread;
    final canThreadAction = canInvoke && hasSelection;
    final markLabel = isUnread ? 'Mark as Read' : 'Mark as Unread';
    final messageMenu = PlatformMenu(
      label: 'Message',
      menus: [
        PlatformMenuItem(
          label: 'Reply',
          onSelected: canThreadAction
              ? () => _appState.triggerMenuAction(ShortcutAction.reply)
              : null,
        ),
        PlatformMenuItem(
          label: 'Reply All',
          onSelected: canThreadAction
              ? () => _appState.triggerMenuAction(ShortcutAction.replyAll)
              : null,
        ),
        PlatformMenuItem(
          label: 'Forward',
          onSelected: canThreadAction
              ? () => _appState.triggerMenuAction(ShortcutAction.forward)
              : null,
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: markLabel,
              onSelected: canThreadAction
                  ? () => _appState.triggerMenuAction(ShortcutAction.toggleRead)
                  : null,
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyU,
                meta: true,
              ),
            ),
          ],
        ),
      ],
    );
    return [
      PlatformMenu(label: 'Tidings', menus: appMenuItems),
      editMenu,
      messageMenu,
    ];
  }

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
              final selectedAccount = _appState.selectedAccount;
              final accentAccountId =
                  _settings.paletteSource == ThemePaletteSource.accountAccent
                  ? _appState.accentAccountId
                  : null;
              EmailAccount? accentAccount;
              if (accentAccountId == null) {
                accentAccount = selectedAccount;
              } else {
                final matches = _appState.accounts
                    .where((account) => account.id == accentAccountId)
                    .toList();
                accentAccount = matches.isNotEmpty
                    ? matches.first
                    : selectedAccount;
              }
              final baseAccent = accentAccount == null
                  ? TidingsTheme.defaultAccent
                  : accentAccount.accentColorValue == null
                  ? accentFromAccount(accentAccount.id)
                  : Color(accentAccount.accentColorValue!);
              final brightness = _settings.themeMode == ThemeMode.system
                  ? WidgetsBinding
                        .instance
                        .platformDispatcher
                        .platformBrightness
                  : (_settings.themeMode == ThemeMode.dark
                        ? Brightness.dark
                        : Brightness.light);
              final accent = resolveAccent(baseAccent, brightness);
              final ready = snapshot.connectionState == ConnectionState.done;
              final home = !ready
                  ? _BootSplash(accent: accent)
                  : _appState.hasAccounts
                  ? HomeScreen(appState: _appState, accent: accent)
                  : OnboardingScreen(appState: _appState, accent: accent);
              final homeKey = ValueKey<String>(
                !ready
                    ? 'boot'
                    : (_appState.hasAccounts ? 'home' : 'onboarding'),
              );
              return PlatformMenuBar(
                menus: _buildMenuBar(),
                child: MaterialApp(
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
                  home: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: KeyedSubtree(key: homeKey, child: home),
                  ),
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
