import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:our_spring_days/core/providers/common_providers.dart';
import 'package:our_spring_days/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App load smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const OurSpringApp(),
      ),
    );

    expect(find.byType(OurSpringApp), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
