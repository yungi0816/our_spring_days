import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:our_spring_days/core/providers/common_providers.dart';
import 'package:our_spring_days/core/providers/user_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('currentUserProvider restores the saved user', () async {
    SharedPreferences.setMockInitialValues({'authenticated_user_id': 'user-a'});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(currentUserProvider), 'user-a');
  });

  test('currentUserProvider saves user changes', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    container.read(currentUserProvider.notifier).signIn('user-b');

    expect(container.read(currentUserProvider), 'user-b');
    expect(prefs.getString('authenticated_user_id'), 'user-b');
  });

  test('currentUserProvider clears the saved user on sign out', () async {
    SharedPreferences.setMockInitialValues({'authenticated_user_id': 'user-c'});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    container.read(currentUserProvider.notifier).signOut();

    expect(container.read(currentUserProvider), '');
    expect(prefs.getString('authenticated_user_id'), isNull);
  });
}
