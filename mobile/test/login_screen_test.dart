import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raahi/features/auth/login_screen.dart';

void main() {
  testWidgets('Login screen renders email/password and toggle',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('Raahi'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text("New here? Create an account"), findsOneWidget);
    expect(find.text('Skip for now (demo mode)'), findsOneWidget);

    // Toggle to sign-up mode.
    await tester.tap(find.text("New here? Create an account"));
    await tester.pump();
    expect(find.text('Create account'), findsOneWidget);
  });
}
