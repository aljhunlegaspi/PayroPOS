// Basic Flutter widget test for PayroPOS

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:payro_pos/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: PayroPOSApp(),
      ),
    );

    // Verify the app builds without errors
    expect(find.byType(PayroPOSApp), findsOneWidget);
  });
}
