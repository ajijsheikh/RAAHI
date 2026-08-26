import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/auth_provider.dart';
import 'routing/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const url = String.fromEnvironment('SUPABASE_URL');
  const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  final enabled = url.isNotEmpty && anonKey.isNotEmpty;

  if (enabled) {
    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  runApp(
    ProviderScope(
      overrides: [supabaseEnabledProvider.overrideWithValue(enabled)],
      child: const RaahiApp(),
    ),
  );
}

class RaahiApp extends ConsumerWidget {
  const RaahiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Warm the auth listener at app start.
    ref.watch(authProvider);

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
    const agent = Color(0xFF0F6E5C); // autonomous-action teal
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme:
          ColorScheme.fromSeed(seedColor: agent, brightness: brightness),
    );
  }
}
