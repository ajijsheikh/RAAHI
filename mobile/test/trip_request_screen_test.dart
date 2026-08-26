import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raahi/features/trip_request/trip_request_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: TripRequestScreen())),
    );
    await tester.pump();
  }

  testWidgets('Trip request renders pre-filled query and preference chips',
      (tester) async {
    await pump(tester);

    // Pre-filled query appears in both the field's value and its hint.
    expect(find.textContaining('Howrah se Salt Lake Sector V'), findsWidgets);
    expect(find.text('Balanced'), findsOneWidget);
    expect(find.text('Fastest'), findsOneWidget);
    expect(find.text('Cheapest'), findsOneWidget);
    expect(find.text('Safest'), findsOneWidget);
  });

  testWidgets('Tapping a preference chip selects it', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Safest'));
    await tester.pump();

    final chip = tester.widget<ChoiceChip>(
      find.ancestor(
        of: find.text('Safest'),
        matching: find.byType(ChoiceChip),
      ),
    );
    expect(chip.selected, isTrue);
  });
}
