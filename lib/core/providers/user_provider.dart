import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_constants.dart';
import 'common_providers.dart';

bool isPartnerAUser(String userId) => userId == AppConstants.partnerAId;

String otherPartnerId(String userId) {
  return isPartnerAUser(userId)
      ? AppConstants.partnerBId
      : AppConstants.partnerAId;
}

final deviceKeyProvider = Provider<String>((ref) {
  const key = 'device_install_key';
  final prefs = ref.watch(sharedPreferencesProvider);
  final savedKey = prefs.getString(key);
  if (savedKey != null && savedKey.isNotEmpty) {
    return savedKey;
  }

  final newKey = const Uuid().v4();
  prefs.setString(key, newKey);
  return newKey;
});

// 현재 로그인 사용자 ID 관리
class UserNotifier extends Notifier<String> {
  static const _key = 'authenticated_user_id';

  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString(_key) ?? '';
  }

  void signIn(String userId) {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) {
      return;
    }

    state = cleanUserId;
    ref.read(sharedPreferencesProvider).setString(_key, cleanUserId);
  }

  void setUser(String userId) {
    signIn(userId);
  }

  void signOut() {
    state = '';
    ref.read(sharedPreferencesProvider).remove(_key);
  }
}

final currentUserProvider = NotifierProvider<UserNotifier, String>(
  UserNotifier.new,
);
