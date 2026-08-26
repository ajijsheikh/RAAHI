import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raahi/main.dart';

void main() {
  testWidgets('App boots into trip request screen (demo mode, no Supabase)',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: RaahiApp()));
    await tester.pumpAndSettle();

    expect(find.text('Raahi'), findsOneWidget);
  });
}
