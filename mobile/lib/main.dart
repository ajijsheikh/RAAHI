import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routing/app_router.dart';

void main() {
  runApp(const ProviderScope(child: RaahiApp()));
}

class RaahiApp extends ConsumerWidget {
  const RaahiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Raahi',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(appRouterProvider),
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ThemeMode.system,
    );
  }

  ThemeData _theme(Brightness brightness) {
    const agent = Color(0xFF0F6E5C); // every autonomous action
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(seedColor: agent, brightness: brightness),
    );
  }
}
