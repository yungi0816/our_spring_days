import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'common_providers.dart';

class UserProfile {
  final String id;
  final String? photoUrl;
  final String? nickname;
  final String? loginId;
  final String? email;
  final String? gender;
  final String? coupleCode;
  final String? partnerUserId;
  final String? linkedCoupleId;
  final bool coupleActive;
  final bool isCoupleDisconnected;
  final bool mustChangePassword;

  UserProfile({
    required this.id,
    this.photoUrl,
    this.nickname,
    this.loginId,
    this.email,
    this.gender,
    this.coupleCode,
    this.partnerUserId,
    this.linkedCoupleId,
    this.coupleActive = false,
    this.isCoupleDisconnected = false,
    this.mustChangePassword = false,
  });

  bool get isRegistered => loginId != null && loginId!.isNotEmpty;

  String get displayName {
    final name = nickname?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return id;
  }

  factory UserProfile.fromMap(Map<String, dynamic> map, String id) {
    return UserProfile(
      id: id,
      photoUrl: map['photoUrl'],
      nickname: map['nickname'],
      loginId: map['loginId'],
      email: map['email'],
      gender: map['gender'],
      coupleCode: map['coupleCode'],
      partnerUserId: map['partnerUserId'],
      linkedCoupleId: map['linkedCoupleId'],
      coupleActive: map['coupleActive'] as bool? ?? false,
      isCoupleDisconnected: map['isCoupleDisconnected'] as bool? ?? false,
      mustChangePassword: map['mustChangePassword'] as bool? ?? false,
    );
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
