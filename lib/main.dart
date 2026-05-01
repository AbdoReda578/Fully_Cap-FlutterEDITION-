import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'core/brand_palette.dart';
import 'state/app_state.dart';
import 'services/permission_bootstrap.dart';
import 'ui/screens/config_error_screen.dart';
import 'ui/screens/family_home_shell.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/widgets/loading_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ask for the common permissions early so the prototype flow is smoother.
  // (Best-effort; failures are ignored in tests / unsupported platforms.)
  await PermissionBootstrap.requestInitialPermissions();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Uncaught error: $error\\n$stack');
    return true;
  };

  runApp(
    ChangeNotifierProvider<AppState>(
      create: (_) => AppState()..initialize(),
      child: const MedReminderApp(),
    ),
  );
}

class MedReminderApp extends StatelessWidget {
  const MedReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.outfitTextTheme();
    final state = context.watch<AppState>();

    return MaterialApp(
      title: 'MedReminder',
      debugShowCheckedModeBanner: false,
      themeMode: state.darkModeEnabled ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: BrandPalette.primaryBlue,
          primary: BrandPalette.primaryViolet,
          secondary: BrandPalette.primaryDeep,
          surface: BrandPalette.surface,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: BrandPalette.background,
        useMaterial3: true,
        textTheme: baseTextTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: BrandPalette.background,
          foregroundColor: BrandPalette.textPrimary,
          elevation: 0,
          titleTextStyle: baseTextTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: BrandPalette.textPrimary,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: BrandPalette.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: BrandPalette.borderSoft),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: BrandPalette.borderSoft),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: BrandPalette.primaryViolet,
              width: 1.6,
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: BrandPalette.surface,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: BrandPalette.surfaceSoft),
          ),
          shadowColor: BrandPalette.shadowSoft,
        ),
        filledButtonTheme: const FilledButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll<Color>(
              BrandPalette.primaryViolet,
            ),
            foregroundColor: WidgetStatePropertyAll<Color>(
              Colors.white,
            ),
          ),
        ),
        outlinedButtonTheme: const OutlinedButtonThemeData(
          style: ButtonStyle(
            foregroundColor: WidgetStatePropertyAll<Color>(
              BrandPalette.primaryViolet,
            ),
            side: WidgetStatePropertyAll<BorderSide>(
              BorderSide(color: BrandPalette.borderStrong),
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: BrandPalette.surfaceSoft,
          selectedColor: BrandPalette.primaryViolet,
          side: const BorderSide(color: BrandPalette.borderSoft),
          labelStyle: baseTextTheme.bodySmall?.copyWith(
            color: BrandPalette.textPrimary,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: BrandPalette.surface,
          indicatorColor: BrandPalette.surfaceSoft,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: BrandPalette.primaryViolet);
            }
            return const IconThemeData(color: BrandPalette.textTertiary);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return baseTextTheme.bodySmall?.copyWith(
                color: BrandPalette.primaryViolet,
                fontWeight: FontWeight.w700,
              );
            }
            return baseTextTheme.bodySmall?.copyWith(
              color: BrandPalette.textTertiary,
            );
          }),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: BrandPalette.primaryViolet,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: BrandPalette.primaryViolet,
          primary: BrandPalette.primaryViolet,
          secondary: BrandPalette.primaryBlue,
          surface: BrandPalette.darkSurface,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: BrandPalette.darkBackground,
        useMaterial3: true,
        textTheme: baseTextTheme.apply(
          bodyColor: BrandPalette.darkTextPrimary,
          displayColor: BrandPalette.darkTextPrimary,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: BrandPalette.darkBackground,
          foregroundColor: BrandPalette.darkTextPrimary,
          elevation: 0,
          titleTextStyle: baseTextTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: BrandPalette.darkTextPrimary,
          ),
        ),
        cardTheme: CardThemeData(
          color: BrandPalette.darkSurface,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: BrandPalette.darkBorder),
          ),
          shadowColor: BrandPalette.shadowSoft,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: BrandPalette.darkSurfaceSoft,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: BrandPalette.darkBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: BrandPalette.darkBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: BrandPalette.primaryViolet,
              width: 1.6,
            ),
          ),
        ),
        filledButtonTheme: const FilledButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll<Color>(
              BrandPalette.primaryViolet,
            ),
            foregroundColor: WidgetStatePropertyAll<Color>(
              BrandPalette.textOnPrimary,
            ),
          ),
        ),
        outlinedButtonTheme: const OutlinedButtonThemeData(
          style: ButtonStyle(
            foregroundColor: WidgetStatePropertyAll<Color>(
              BrandPalette.darkTextPrimary,
            ),
            side: WidgetStatePropertyAll<BorderSide>(
              BorderSide(color: BrandPalette.darkBorder),
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: BrandPalette.darkSurfaceSoft,
          selectedColor: BrandPalette.primaryDeep,
          side: const BorderSide(color: BrandPalette.darkBorder),
          labelStyle: baseTextTheme.bodySmall?.copyWith(
            color: BrandPalette.darkTextPrimary,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: BrandPalette.darkSurface,
          indicatorColor: BrandPalette.darkSurfaceSoft,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: BrandPalette.primaryViolet);
            }
            return const IconThemeData(color: BrandPalette.darkTextTertiary);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return baseTextTheme.bodySmall?.copyWith(
                color: BrandPalette.primaryViolet,
                fontWeight: FontWeight.w700,
              );
            }
            return baseTextTheme.bodySmall?.copyWith(
              color: BrandPalette.darkTextTertiary,
            );
          }),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: BrandPalette.primaryViolet,
        ),
      ),
      home: const _RootScreen(),
    );
  }
}

class _RootScreen extends StatefulWidget {
  const _RootScreen();

  @override
  State<_RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<_RootScreen> {
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _splashDone = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return const SplashScreen();
    }

    return Consumer<AppState>(
      builder: (BuildContext context, AppState state, _) {
        if (state.isInitializing) {
          return const LoadingView();
        }

        if (!state.hasToken) {
          if (state.configErrorMessage != null) {
            return ConfigErrorScreen(message: state.configErrorMessage!);
          }
          return const LoginScreen();
        }

        if (state.isFamilyRole) {
          return const FamilyHomeShell();
        }

        return const HomeShell();
      },
    );
  }
}
