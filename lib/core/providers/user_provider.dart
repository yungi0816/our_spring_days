import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import 'common_providers.dart';

bool isPartnerAUser(String userId) => userId == AppConstants.partnerAId;

String otherPartnerId(String userId) {
  return isPartnerAUser(userId)
      ? AppConstants.partnerBId
      : AppConstants.partnerAId;
}

// 현재 사용자 ID 관리
class UserNotifier extends Notifier<String> {
  static const _key = 'selected_user_id';
  static const _defaultUser = AppConstants.partnerAId;
  static const _validUsers = {AppConstants.partnerAId, AppConstants.partnerBId};

  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final savedUser = prefs.getString(_key);

    if (savedUser != null && _validUsers.contains(savedUser)) {
      return savedUser;
    }

    return _defaultUser;
  }

  void setUser(String userId) {
    if (!_validUsers.contains(userId)) {
      return;
    }

    state = userId;
    ref.read(sharedPreferencesProvider).setString(_key, userId);
  }
}

final currentUserProvider = NotifierProvider<UserNotifier, String>(
  UserNotifier.new,
);
