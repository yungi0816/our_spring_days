import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:our_spring_days/core/constants/app_constants.dart';
import 'package:our_spring_days/core/providers/common_providers.dart';
import 'package:our_spring_days/core/providers/user_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('currentUserProvider restores the saved user', () async {
    SharedPreferences.setMockInitialValues({
      'selected_user_id': AppConstants.partnerBId,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(currentUserProvider), AppConstants.partnerBId);
  });

  test('currentUserProvider saves user changes', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    container
        .read(currentUserProvider.notifier)
        .setUser(AppConstants.partnerBId);

    expect(container.read(currentUserProvider), AppConstants.partnerBId);
    expect(prefs.getString('selected_user_id'), AppConstants.partnerBId);
  });
}
