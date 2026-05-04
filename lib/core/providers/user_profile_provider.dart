import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'common_providers.dart';

class UserProfile {
  final String id;
  final String? photoUrl;

  UserProfile({required this.id, this.photoUrl});

  factory UserProfile.fromMap(Map<String, dynamic> map, String id) {
    return UserProfile(id: id, photoUrl: map['photoUrl']);
  }
}

final userProfileProvider = StreamProvider.family<UserProfile, String>((
  ref,
  userId,
) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return firebaseService
      .getUserProfileStream(userId)
      .map((data) => UserProfile.fromMap(data, userId));
});
