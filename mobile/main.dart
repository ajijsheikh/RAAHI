import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'routing/app_router.dart';

void main() {
  runApp(const RaahiApp());
}

class RaahiApp extends ConsumerWidget {
  const RaahiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Raahi',
      routerDelegate: goRouter.routerDelegate,
      routeInformationProvider: goRouter.routeInformationProvider,
      routeInformationParser: goRouter.routeInformationParser,
      routeInformationRedirection: goRouter.routeInformationRedirection,
      resetAppNavigator: true,
      theme: _theme(),
      darkTheme: _theme(brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      builder: (context, child) {
        // Add global error handling
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: true,
          ),
          child: child!,
        );
      },
    );
  }

  ThemeData _theme([Brightness brightness = Brightness.light]) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        brightness: brightness,
      ),
      scaffoldBackgroundColor: brightness == Brightness.light
          ? Colors.grey[50]!
          : Colors.grey[900],
    );
  }
}