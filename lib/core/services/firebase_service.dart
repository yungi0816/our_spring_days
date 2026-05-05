import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../providers/album_provider.dart';
import '../providers/mission_provider.dart';
import '../providers/map_provider.dart';
import '../providers/route_models.dart';

class PhotoUploadException implements Exception {
  final String message;
  final Object? cause;

  const PhotoUploadException(this.message, [this.cause]);

  @override
  String toString() => message;
}

class MemberSettingsException implements Exception {
  final String message;

  const MemberSettingsException(this.message);

  @override
  String toString() => message;
}

class MemberSignupResult {
  final String userId;
  final String coupleCode;

  const MemberSignupResult({required this.userId, required this.coupleCode});
}

class MemberLoginResult {
  final String userId;
  final bool requiresDeviceVerification;
  final bool mustChangePassword;

  const MemberLoginResult({
    required this.userId,
    required this.requiresDeviceVerification,
    required this.mustChangePassword,
  });
}

class EmailVerificationRequest {
  final String id;
  final String maskedEmail;
  final String debugCode;
  final DateTime expiresAt;

  const EmailVerificationRequest({
    required this.id,
    required this.maskedEmail,
    required this.debugCode,
    required this.expiresAt,
  });
}

class _CoupleCodeCollisionException implements Exception {}

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
  );
  static const String _cloudinaryUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
  );
  static const String _cloudinaryFolder = String.fromEnvironment(
    'CLOUDINARY_FOLDER',
    defaultValue: 'our_spring_days',
  );

  final String coupleId = AppConstants.coupleId;

  // --- 미션 관련 로직 ---
  Stream<List<Mission>> getMissionStream() {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('missions')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Mission.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> addMission(Mission mission) async {
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('missions')
        .doc(mission.id)
        .set(mission.toMap());
  }

  Future<void> updateMission(
    String id,
    String newContent,
    DateTime? deadline,
  ) async {
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('missions')
        .doc(id)
        .update({
          'content': newContent,
          'deadline': deadline != null ? Timestamp.fromDate(deadline) : null,
        });
  }

  Future<void> deleteMission(String id) async {
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('missions')
        .doc(id)
        .delete();
  }

  Future<void> completeMission(
    String id,
    String proofImageUrl,
    String userId,
  ) async {
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('missions')
        .doc(id)
        .update({
          'isCompleted': true,
          'proofImageUrl': proofImageUrl,
          'winnerId': userId,
          'completedAt': Timestamp.fromDate(DateTime.now()),
        });
  }

  // --- 지도(장소) 관련 로직 ---
  Future<void> addDateSpot(DateSpot spot) async {
    final spotRef = _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('date_spots')
        .doc(spot.id);
    final batch = _firestore.batch()..set(spotRef, spot.toMap());
    _syncSpotAlbumEntry(batch, spot);
    await batch.commit();
  }

  Future<void> updateDateSpot(DateSpot spot) async {
    final spotRef = _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('date_spots')
        .doc(spot.id);
    final batch = _firestore.batch()..set(spotRef, spot.toMap());
    _syncSpotAlbumEntry(batch, spot);
    await batch.commit();
  }

  Future<void> deleteDateSpot(String id) async {
    final spotRef = _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('date_spots')
        .doc(id);
    final albumRef = _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('albums')
        .doc(_spotAlbumId(id));
    final batch = _firestore.batch()
      ..delete(spotRef)
      ..delete(albumRef);
    await batch.commit();
  }

  Stream<List<DateSpot>> getDateSpotStream() {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('date_spots')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DateSpot.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  void _syncSpotAlbumEntry(WriteBatch batch, DateSpot spot) {
    final albumRef = _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('albums')
        .doc(_spotAlbumId(spot.id));
    if (spot.imageUrls.isEmpty) {
      batch.delete(albumRef);
      return;
    }

    batch.set(
      albumRef,
      AlbumEntry(
        id: _spotAlbumId(spot.id),
        title: spot.name,
        imageUrls: spot.imageUrls,
        creatorId: spot.creatorId,
        placeName: spot.name,
        address: spot.address,
        position: spot.position,
        sourceType: 'spot',
        sourceId: spot.id,
        timestamp: spot.timestamp,
      ).toMap(),
    );
  }

  String _spotAlbumId(String spotId) => 'spot_$spotId';

  Future<void> updateSharedUserLocation(String userId, LatLng position) async {
    final normalizedUserId = normalizeMapUserId(userId);
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('shared_locations')
        .doc(normalizedUserId)
        .set({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        }, SetOptions(merge: true));
  }

  Stream<List<SharedUserLocation>> getSharedUserLocationStream() {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('shared_locations')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SharedUserLocation.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // --- 여행 루트 기록 로직 ---
  Future<void> setTravelRoute(TravelRoute route) async {
    final ref = _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('travel_routes')
        .doc(route.id);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final existing = snapshot.data();

      if (existing != null &&
          existing['endTime'] != null &&
          route.endTime == null) {
        return;
      }

      transaction.set(ref, route.toMap());
    });
  }

  Future<void> deleteTravelRoute(String id) async {
    final routeRef = _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('travel_routes')
        .doc(id);
    await _deleteQuery(routeRef.collection('comments'));
    await routeRef.delete();
  }

  Stream<List<TravelRoute>> getTravelRouteStream() {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('travel_routes')
        .orderBy('startTime', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TravelRoute.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<List<RouteComment>> getRouteCommentStream(String routeId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('travel_routes')
        .doc(routeId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RouteComment.fromMap(doc.data(), doc.id, routeId))
              .toList(),
        );
  }

  Future<void> addRouteComment(String routeId, RouteComment comment) async {
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('travel_routes')
        .doc(routeId)
        .collection('comments')
        .doc(comment.id)
        .set(comment.toMap());
  }

  Future<void> deleteRouteComment(String routeId, String commentId) async {
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('travel_routes')
        .doc(routeId)
        .collection('comments')
        .doc(commentId)
        .delete();
  }

  Future<void> updateTravelRouteFields(
    String routeId,
    Map<String, dynamic> fields,
  ) async {
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('travel_routes')
        .doc(routeId)
        .update(fields);
  }

  // --- 루트 그룹 관련 로직 ---
  Stream<List<RouteGroup>> getRouteGroupStream() {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('route_groups')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RouteGroup.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> addRouteGroup(RouteGroup group) async {
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('route_groups')
        .doc(group.id)
        .set(group.toMap());
  }

  Future<void> deleteRouteGroup(String groupId) async {
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('route_groups')
        .doc(groupId)
        .delete();
  }

  // --- 장소 코멘트 관련 로직 ---
  Stream<List<SpotComment>> getSpotCommentStream(String spotId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('date_spots')
        .doc(spotId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SpotComment.fromMap(doc.data(), doc.id, spotId))
              .toList(),
        );
  }

  Future<void> addSpotComment(String spotId, SpotComment comment) async {
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('date_spots')
        .doc(spotId)
        .collection('comments')
        .doc(comment.id)
        .set(comment.toMap());
  }

  Future<void> deleteSpotComment(String spotId, String commentId) async {
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('date_spots')
        .doc(spotId)
        .collection('comments')
        .doc(commentId)
        .delete();
  }

  // --- 앨범 코멘트 관련 로직 ---
  Stream<List<AlbumComment>> getAlbumCommentStream(String albumId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('albums')
        .doc(albumId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AlbumComment.fromMap(doc.data(), doc.id, albumId))
              .toList(),
        );
  }

  Future<void> addAlbumComment(String albumId, AlbumComment comment) async {
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('albums')
        .doc(albumId)
        .collection('comments')
        .doc(comment.id)
        .set(comment.toMap());
  }

  Future<void> deleteAlbumComment(String albumId, String commentId) async {
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('albums')
        .doc(albumId)
        .collection('comments')
        .doc(commentId)
        .delete();
  }

  // --- 앨범 관련 로직 ---
  Stream<List<AlbumEntry>> getAlbumStream() {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('albums')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AlbumEntry.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> addAlbumEntry(AlbumEntry entry) async {
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('albums')
        .doc(entry.id)
        .set(entry.toMap());
  }

  // --- 사용자 프로필 로직 ---
  Stream<Map<String, dynamic>> getUserProfileStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.data() ?? {});
  }

  Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .set(data, SetOptions(merge: true));
  }

  Future<void> resetUserProfilePhoto(String userId) async {
    await _firestore.collection('users').doc(userId).set({
      'photoUrl': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  Future<MemberSignupResult> signUpMember({
    required String nickname,
    required String loginId,
    required String password,
    required String gender,
    required String deviceKey,
  }) async {
    await _ensureFirebaseAuthSession();
    final userRef = _firestore.collection('users').doc();
    final coupleCode = await _createMemberAccount(
      userId: userRef.id,
      nickname: nickname,
      loginId: loginId,
      password: password,
      gender: gender,
      deviceKey: deviceKey,
    );
    await _rememberFirebaseAuthUser(userRef.id);
    return MemberSignupResult(userId: userRef.id, coupleCode: coupleCode);
  }

  Future<MemberLoginResult> loginMember({
    required String loginId,
    required String password,
    required String deviceKey,
  }) async {
    await _ensureFirebaseAuthSession();
    final normalizedLoginId = _normalizeLoginId(loginId);
    if (normalizedLoginId.isEmpty || password.isEmpty) {
      throw const MemberSettingsException('아이디와 비밀번호를 입력해 주세요.');
    }

    final loginSnapshot = await _firestore
        .collection('login_ids')
        .doc(normalizedLoginId)
        .get();
    final userId = loginSnapshot.data()?['userId']?.toString();
    if (userId == null || userId.isEmpty) {
      throw const MemberSettingsException('아이디 또는 비밀번호가 올바르지 않습니다.');
    }

    final userSnapshot = await _firestore.collection('users').doc(userId).get();
    final user = userSnapshot.data();
    if (user == null) {
      throw const MemberSettingsException('아이디 또는 비밀번호가 올바르지 않습니다.');
    }

    final savedHash = user['passwordHash']?.toString();
    if (savedHash != _passwordHash(normalizedLoginId, password)) {
      throw const MemberSettingsException('아이디 또는 비밀번호가 올바르지 않습니다.');
    }

    final mustChangePassword = user['mustChangePassword'] as bool? ?? false;

    await _registerLoginDevice(userId: userId, deviceKey: deviceKey);
    await _rememberFirebaseAuthUser(userId);
    return MemberLoginResult(
      userId: userId,
      requiresDeviceVerification: false,
      mustChangePassword: mustChangePassword,
    );
  }

  Future<bool> isDeviceAuthorized({
    required String userId,
    required String deviceKey,
  }) async {
    await _ensureFirebaseAuthSession();
    if (userId.trim().isEmpty || deviceKey.trim().isEmpty) {
      return false;
    }

    final snapshot = await _firestore.collection('users').doc(userId).get();
    final user = snapshot.data();
    if (user == null) {
      return false;
    }

    final deviceKeys = (user['deviceKeys'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .toSet();
    final authorized = deviceKeys.contains(deviceKey);
    if (authorized) {
      await _rememberFirebaseAuthUser(userId);
    }
    return authorized;
  }

  Future<EmailVerificationRequest> requestNewDeviceCode(String userId) async {
    final snapshot = await _firestore.collection('users').doc(userId).get();
    final user = snapshot.data();
    final email = user?['email']?.toString();
    if (email == null || email.isEmpty) {
      throw const MemberSettingsException('등록된 이메일이 없어 기기 인증을 진행할 수 없습니다.');
    }

    return _createEmailVerificationCode(
      email: email,
      purpose: 'new_device_login',
      userId: userId,
    );
  }

  Future<void> completeNewDeviceLogin({
    required String requestId,
    required String code,
    required String userId,
    required String deviceKey,
  }) async {
    final data = await _verifyEmailCode(
      requestId: requestId,
      code: code,
      expectedPurpose: 'new_device_login',
    );
    if (data['userId']?.toString() != userId) {
      throw const MemberSettingsException('인증 요청 정보가 일치하지 않습니다.');
    }
    await _registerLoginDevice(userId: userId, deviceKey: deviceKey);
  }

  Future<EmailVerificationRequest> requestFindLoginIdCode(String email) async {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty) {
      throw const MemberSettingsException('이메일을 입력해 주세요.');
    }

    final emailSnapshot = await _firestore
        .collection('emails')
        .doc(normalizedEmail)
        .get();
    final userId = emailSnapshot.data()?['userId']?.toString();
    if (userId == null || userId.isEmpty) {
      throw const MemberSettingsException('해당 이메일로 가입된 계정이 없습니다.');
    }

    return _createEmailVerificationCode(
      email: normalizedEmail,
      purpose: 'find_login_id',
      userId: userId,
    );
  }

  Future<String> completeFindLoginId({
    required String requestId,
    required String code,
  }) async {
    final data = await _verifyEmailCode(
      requestId: requestId,
      code: code,
      expectedPurpose: 'find_login_id',
    );
    final userId = data['userId']?.toString();
    if (userId == null || userId.isEmpty) {
      throw const MemberSettingsException('회원 정보를 찾을 수 없습니다.');
    }

    final snapshot = await _firestore.collection('users').doc(userId).get();
    final loginId = snapshot.data()?['loginId']?.toString();
    if (loginId == null || loginId.isEmpty) {
      throw const MemberSettingsException('아이디 정보를 찾을 수 없습니다.');
    }
    await _queuePlainEmail(
      email: data['email']?.toString() ?? '',
      subject: '비비랑 우리 아이디 안내',
      text: '가입하신 비비랑 우리 아이디는 $loginId 입니다.',
    );
    return loginId;
  }

  Future<EmailVerificationRequest> requestPasswordResetCode({
    required String loginId,
    required String email,
  }) async {
    final normalizedLoginId = _normalizeLoginId(loginId);
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedLoginId.isEmpty || normalizedEmail.isEmpty) {
      throw const MemberSettingsException('아이디와 이메일을 입력해 주세요.');
    }

    final loginSnapshot = await _firestore
        .collection('login_ids')
        .doc(normalizedLoginId)
        .get();
    final userId = loginSnapshot.data()?['userId']?.toString();
    if (userId == null || userId.isEmpty) {
      throw const MemberSettingsException('일치하는 회원 정보가 없습니다.');
    }

    final userSnapshot = await _firestore.collection('users').doc(userId).get();
    final user = userSnapshot.data();
    if (user?['email']?.toString() != normalizedEmail) {
      throw const MemberSettingsException('일치하는 회원 정보가 없습니다.');
    }

    return _createEmailVerificationCode(
      email: normalizedEmail,
      purpose: 'password_reset',
      userId: userId,
    );
  }

  Future<String> completePasswordReset({
    required String requestId,
    required String code,
  }) async {
    final data = await _verifyEmailCode(
      requestId: requestId,
      code: code,
      expectedPurpose: 'password_reset',
    );
    final userId = data['userId']?.toString();
    if (userId == null || userId.isEmpty) {
      throw const MemberSettingsException('회원 정보를 찾을 수 없습니다.');
    }

    final userRef = _firestore.collection('users').doc(userId);
    final userSnapshot = await userRef.get();
    final loginId = userSnapshot.data()?['loginId']?.toString();
    if (loginId == null || loginId.isEmpty) {
      throw const MemberSettingsException('회원 정보를 찾을 수 없습니다.');
    }

    final temporaryPassword = _generateTemporaryPassword();
    await userRef.set({
      'passwordHash': _passwordHash(loginId, temporaryPassword),
      'mustChangePassword': true,
      'temporaryPasswordIssuedAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));
    await _queuePlainEmail(
      email: data['email']?.toString() ?? '',
      subject: '비비랑 우리 임시 비밀번호 안내',
      text: '임시 비밀번호는 $temporaryPassword 입니다. 로그인 후 새 비밀번호로 변경해 주세요.',
    );
    return temporaryPassword;
  }

  Future<void> setMemberPassword({
    required String userId,
    required String newPassword,
  }) async {
    if (newPassword.isEmpty) {
      throw const MemberSettingsException('새 비밀번호를 입력해 주세요.');
    }

    final userRef = _firestore.collection('users').doc(userId);
    final userSnapshot = await userRef.get();
    final loginId = userSnapshot.data()?['loginId']?.toString();
    if (loginId == null || loginId.isEmpty) {
      throw const MemberSettingsException('회원 정보를 찾을 수 없습니다.');
    }

    await userRef.set({
      'passwordHash': _passwordHash(loginId, newPassword),
      'mustChangePassword': false,
      'passwordChangedAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));
  }

  Future<String> findLoginIdByPartnerCoupleCode(
    String partnerCoupleCode,
  ) async {
    final partner = await getMemberByCoupleCode(partnerCoupleCode);
    final userId = partner?['partnerUserId']?.toString();
    if (userId == null || userId.isEmpty) {
      throw const MemberSettingsException('커플 등록된 상대방 코드를 입력해 주세요.');
    }

    final userSnapshot = await _firestore.collection('users').doc(userId).get();
    final loginId = userSnapshot.data()?['loginId']?.toString();
    if (loginId == null || loginId.isEmpty) {
      throw const MemberSettingsException('아이디 정보를 찾을 수 없습니다.');
    }
    return loginId;
  }

  Future<void> resetPasswordWithPartnerCoupleCode({
    required String loginId,
    required String partnerCoupleCode,
    required String newPassword,
  }) async {
    final normalizedLoginId = _normalizeLoginId(loginId);
    if (normalizedLoginId.isEmpty ||
        partnerCoupleCode.trim().isEmpty ||
        newPassword.isEmpty) {
      throw const MemberSettingsException('아이디, 상대방 커플 코드, 새 비밀번호를 입력해 주세요.');
    }

    final loginSnapshot = await _firestore
        .collection('login_ids')
        .doc(normalizedLoginId)
        .get();
    final userId = loginSnapshot.data()?['userId']?.toString();
    if (userId == null || userId.isEmpty) {
      throw const MemberSettingsException('일치하는 회원 정보가 없습니다.');
    }

    final partner = await getMemberByCoupleCode(partnerCoupleCode);
    final partnerUserId = partner?['id']?.toString();
    final linkedUserId = partner?['partnerUserId']?.toString();
    if (partnerUserId == null ||
        partnerUserId.isEmpty ||
        linkedUserId != userId) {
      throw const MemberSettingsException('상대방 커플 코드가 일치하지 않습니다.');
    }

    await _firestore.collection('users').doc(userId).set({
      'passwordHash': _passwordHash(normalizedLoginId, newPassword),
      'mustChangePassword': false,
      'passwordChangedAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));
  }

  Future<String> _createMemberAccount({
    required String userId,
    required String nickname,
    required String loginId,
    required String password,
    required String gender,
    required String deviceKey,
  }) async {
    final normalizedLoginId = _normalizeLoginId(loginId);
    final cleanNickname = nickname.trim();
    if (cleanNickname.isEmpty ||
        normalizedLoginId.isEmpty ||
        password.isEmpty ||
        gender.trim().isEmpty) {
      throw const MemberSettingsException('회원 정보를 모두 입력해 주세요.');
    }

    for (var attempt = 0; attempt < 12; attempt++) {
      final code = _generateCoupleCode();
      try {
        await _firestore.runTransaction((transaction) async {
          final userRef = _firestore.collection('users').doc(userId);
          final loginRef = _firestore
              .collection('login_ids')
              .doc(normalizedLoginId);
          final codeRef = _firestore.collection('couple_codes').doc(code);

          final loginSnapshot = await transaction.get(loginRef);
          final codeSnapshot = await transaction.get(codeRef);

          if (loginSnapshot.exists) {
            throw const MemberSettingsException('이미 사용 중인 아이디입니다.');
          }
          if (codeSnapshot.exists) {
            throw _CoupleCodeCollisionException();
          }

          final now = Timestamp.fromDate(DateTime.now());
          transaction.set(userRef, {
            'nickname': cleanNickname,
            'loginId': normalizedLoginId,
            'passwordHash': _passwordHash(normalizedLoginId, password),
            'gender': gender,
            'coupleCode': code,
            'coupleActive': false,
            'isCoupleDisconnected': false,
            'deviceKeys': deviceKey.isEmpty ? <String>[] : [deviceKey],
            'mustChangePassword': false,
            'registeredAt': now,
            'updatedAt': now,
          }, SetOptions(merge: true));
          transaction.set(loginRef, {'userId': userId, 'createdAt': now});
          transaction.set(codeRef, {
            'userId': userId,
            'nickname': cleanNickname,
            'createdAt': now,
          });
        });
        await _rememberFirebaseAuthUser(userId);
        return code;
      } on _CoupleCodeCollisionException {
        continue;
      }
    }

    throw const MemberSettingsException('커플 코드를 생성하지 못했습니다. 다시 시도해 주세요.');
  }

  Future<String> registerMember({
    required String userId,
    required String nickname,
    required String loginId,
    required String password,
    required String gender,
  }) async {
    final normalizedLoginId = _normalizeLoginId(loginId);
    final cleanNickname = nickname.trim();
    if (cleanNickname.isEmpty ||
        normalizedLoginId.isEmpty ||
        password.isEmpty ||
        gender.trim().isEmpty) {
      throw const MemberSettingsException('회원 정보를 모두 입력해 주세요.');
    }

    for (var attempt = 0; attempt < 12; attempt++) {
      final code = _generateCoupleCode();
      try {
        await _firestore.runTransaction((transaction) async {
          final userRef = _firestore.collection('users').doc(userId);
          final loginRef = _firestore
              .collection('login_ids')
              .doc(normalizedLoginId);
          final codeRef = _firestore.collection('couple_codes').doc(code);

          final loginSnapshot = await transaction.get(loginRef);
          final codeSnapshot = await transaction.get(codeRef);

          if (loginSnapshot.exists &&
              loginSnapshot.data()?['userId'] != userId) {
            throw const MemberSettingsException('이미 사용 중인 아이디입니다.');
          }
          if (codeSnapshot.exists) {
            throw _CoupleCodeCollisionException();
          }

          final now = Timestamp.fromDate(DateTime.now());
          transaction.set(userRef, {
            'nickname': cleanNickname,
            'loginId': normalizedLoginId,
            'passwordHash': _passwordHash(normalizedLoginId, password),
            'gender': gender,
            'coupleCode': code,
            'coupleActive': false,
            'isCoupleDisconnected': false,
            'registeredAt': now,
            'updatedAt': now,
          }, SetOptions(merge: true));
          transaction.set(loginRef, {
            'userId': userId,
            'createdAt': now,
          }, SetOptions(merge: true));
          transaction.set(codeRef, {
            'userId': userId,
            'nickname': cleanNickname,
            'createdAt': now,
          });
        });
        await _rememberFirebaseAuthUser(userId);
        return code;
      } on _CoupleCodeCollisionException {
        continue;
      }
    }

    throw const MemberSettingsException('커플 코드를 생성하지 못했습니다. 다시 시도해 주세요.');
  }

  Future<Map<String, dynamic>?> getMemberByCoupleCode(String code) async {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      return null;
    }

    final codeSnapshot = await _firestore
        .collection('couple_codes')
        .doc(normalizedCode)
        .get();
    final userId = codeSnapshot.data()?['userId']?.toString();
    if (userId == null || userId.isEmpty) {
      return null;
    }

    final userSnapshot = await _firestore.collection('users').doc(userId).get();
    final data = userSnapshot.data();
    if (data == null) {
      return null;
    }
    return {'id': userId, ...data};
  }

  Future<String> linkCouple({
    required String currentUserId,
    required String partnerCoupleCode,
  }) async {
    final normalizedCode = partnerCoupleCode.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      throw const MemberSettingsException('상대방의 커플 코드를 입력해 주세요.');
    }

    var partnerNickname = '';
    String? linkedPartnerUserId;
    final currentAuthUid = await _currentFirebaseAuthUid();
    await _firestore.runTransaction((transaction) async {
      final selfRef = _firestore.collection('users').doc(currentUserId);
      final codeRef = _firestore.collection('couple_codes').doc(normalizedCode);
      final coupleRef = _firestore.collection('couples').doc(coupleId);

      final selfSnapshot = await transaction.get(selfRef);
      final codeSnapshot = await transaction.get(codeRef);
      final coupleSnapshot = await transaction.get(coupleRef);
      final self = selfSnapshot.data();
      final codeData = codeSnapshot.data();
      final partnerUserId = codeData?['userId']?.toString();

      if (self == null || self['loginId'] == null) {
        throw const MemberSettingsException('먼저 회원가입을 완료해 주세요.');
      }
      if (partnerUserId == null || partnerUserId.isEmpty) {
        throw const MemberSettingsException('존재하지 않는 커플 코드입니다.');
      }
      if (partnerUserId == currentUserId) {
        throw const MemberSettingsException('본인의 커플 코드는 등록할 수 없습니다.');
      }

      final partnerRef = _firestore.collection('users').doc(partnerUserId);
      final partnerSnapshot = await transaction.get(partnerRef);
      final partner = partnerSnapshot.data();
      if (partner == null) {
        throw const MemberSettingsException('상대방 회원 정보를 찾을 수 없습니다.');
      }

      partnerNickname = partner['nickname']?.toString() ?? partnerUserId;
      linkedPartnerUserId = partnerUserId;
      final existingMembers =
          (coupleSnapshot.data()?['memberIds'] as List<dynamic>? ?? const [])
              .map((value) => value.toString())
              .where((value) => value.isNotEmpty)
              .toSet();
      final nextMembers = {currentUserId, partnerUserId};
      if (existingMembers.isNotEmpty &&
          (existingMembers.length != nextMembers.length ||
              !existingMembers.containsAll(nextMembers))) {
        throw const MemberSettingsException('이미 다른 커플로 잠긴 공유 공간입니다.');
      }
      final partnerAuthUids =
          (partner['firebaseAuthUids'] as List<dynamic>? ?? const [])
              .map((value) => value.toString())
              .where((value) => value.isNotEmpty)
              .toSet();
      final partnerAuthUid = partner['firebaseAuthUid']?.toString();
      if (partnerAuthUid != null && partnerAuthUid.isNotEmpty) {
        partnerAuthUids.add(partnerAuthUid);
      }
      final authUids = {
        if (currentAuthUid != null && currentAuthUid.isNotEmpty) currentAuthUid,
        ...partnerAuthUids,
      }.toList();
      final now = Timestamp.fromDate(DateTime.now());
      final updates = {
        'coupleActive': true,
        'isCoupleDisconnected': false,
        'linkedCoupleId': coupleId,
        'updatedAt': now,
      };
      transaction.set(coupleRef, {
        'memberIds': nextMembers.toList(),
        'authUids': authUids,
        'active': true,
        'updatedAt': now,
      }, SetOptions(merge: true));
      transaction.set(selfRef, {
        ...updates,
        'partnerUserId': partnerUserId,
      }, SetOptions(merge: true));
      transaction.set(partnerRef, {
        ...updates,
        'partnerUserId': currentUserId,
      }, SetOptions(merge: true));
    });

    await _rememberFirebaseAuthUser(
      currentUserId,
      linkedCoupleId: coupleId,
      partnerUserId: linkedPartnerUserId,
    );
    return partnerNickname;
  }

  Future<void> unlinkCouple({
    required String currentUserId,
    required bool deleteRecords,
  }) async {
    final selfRef = _firestore.collection('users').doc(currentUserId);
    final selfSnapshot = await selfRef.get();
    final self = selfSnapshot.data();
    final partnerUserId = self?['partnerUserId']?.toString();

    if (deleteRecords) {
      await _deleteCoupleRecords();
    } else {
      await _markCoupleRecordsDisconnected();
    }

    final now = Timestamp.fromDate(DateTime.now());
    final data = {
      'coupleActive': false,
      'isCoupleDisconnected': !deleteRecords,
      'coupleRecordsDeletedAt': deleteRecords ? now : FieldValue.delete(),
      'coupleDisconnectedAt': now,
      'updatedAt': now,
    };

    final batch = _firestore.batch();
    batch.set(selfRef, data, SetOptions(merge: true));
    if (partnerUserId != null && partnerUserId.isNotEmpty) {
      batch.set(_firestore.collection('users').doc(partnerUserId), {
        ...data,
        'partnerUserId': currentUserId,
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> _registerLoginDevice({
    required String userId,
    required String deviceKey,
  }) async {
    if (deviceKey.trim().isEmpty) {
      return;
    }

    await _firestore.collection('users').doc(userId).set({
      'deviceKeys': FieldValue.arrayUnion([deviceKey]),
      'lastLoginAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));
  }

  Future<void> _ensureFirebaseAuthSession() async {
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'operation-not-allowed') {
        throw const MemberSettingsException(
          'Firebase 콘솔에서 Authentication > Anonymous 로그인을 켜 주세요.',
        );
      }
      throw MemberSettingsException('Firebase 인증 실패: ${e.message ?? e.code}');
    } catch (e) {
      throw MemberSettingsException('Firebase 인증 실패: $e');
    }
  }

  Future<String?> _currentFirebaseAuthUid() async {
    await _ensureFirebaseAuthSession();
    return FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _rememberFirebaseAuthUser(
    String userId, {
    String? linkedCoupleId,
    String? partnerUserId,
  }) async {
    final authUid = await _currentFirebaseAuthUid();
    if (authUid == null || authUid.isEmpty || userId.trim().isEmpty) {
      return;
    }

    final userRef = _firestore.collection('users').doc(userId);
    final userData = (await userRef.get()).data();
    final resolvedCoupleId =
        linkedCoupleId ?? userData?['linkedCoupleId']?.toString();
    final resolvedPartnerId =
        partnerUserId ?? userData?['partnerUserId']?.toString();
    final now = Timestamp.fromDate(DateTime.now());
    final authUserData = <String, dynamic>{
      'userId': userId,
      'updatedAt': now,
      if (resolvedCoupleId != null && resolvedCoupleId.isNotEmpty)
        'linkedCoupleId': resolvedCoupleId,
      if (resolvedPartnerId != null && resolvedPartnerId.isNotEmpty)
        'partnerUserId': resolvedPartnerId,
    };

    final batch = _firestore.batch()
      ..set(
        _firestore.collection('auth_users').doc(authUid),
        authUserData,
        SetOptions(merge: true),
      )
      ..set(userRef, {
        'firebaseAuthUid': authUid,
        'firebaseAuthUids': FieldValue.arrayUnion([authUid]),
        'updatedAt': now,
      }, SetOptions(merge: true));

    if (resolvedCoupleId != null && resolvedCoupleId.isNotEmpty) {
      batch.set(
        _firestore.collection('couples').doc(resolvedCoupleId),
        {
          'memberIds': FieldValue.arrayUnion([userId]),
          'authUids': FieldValue.arrayUnion([authUid]),
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  String _normalizeLoginId(String loginId) {
    return loginId.trim().toLowerCase();
  }

  String _normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }

  String _passwordHash(String loginId, String password) {
    return sha256.convert(utf8.encode('$loginId:$password')).toString();
  }

  String _verificationCodeHash(String email, String purpose, String code) {
    return sha256.convert(utf8.encode('$purpose:$email:$code')).toString();
  }

  Future<EmailVerificationRequest> _createEmailVerificationCode({
    required String email,
    required String purpose,
    required String userId,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    final code = (100000 + Random.secure().nextInt(900000)).toString();
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(minutes: 10));
    final requestRef = _firestore.collection('email_verification_codes').doc();

    await requestRef.set({
      'email': normalizedEmail,
      'purpose': purpose,
      'userId': userId,
      'codeHash': _verificationCodeHash(normalizedEmail, purpose, code),
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(expiresAt),
    });

    await _queueEmailCode(
      email: normalizedEmail,
      code: code,
      purpose: purpose,
      expiresAt: expiresAt,
    );

    return EmailVerificationRequest(
      id: requestRef.id,
      maskedEmail: _maskEmail(normalizedEmail),
      debugCode: code,
      expiresAt: expiresAt,
    );
  }

  Future<Map<String, dynamic>> _verifyEmailCode({
    required String requestId,
    required String code,
    required String expectedPurpose,
  }) async {
    final requestRef = _firestore
        .collection('email_verification_codes')
        .doc(requestId);
    final snapshot = await requestRef.get();
    final data = snapshot.data();
    if (data == null) {
      throw const MemberSettingsException('인증번호 요청을 찾을 수 없습니다.');
    }
    if (data['purpose']?.toString() != expectedPurpose) {
      throw const MemberSettingsException('인증 요청 정보가 일치하지 않습니다.');
    }
    if (data['usedAt'] != null) {
      throw const MemberSettingsException('이미 사용된 인증번호입니다.');
    }

    final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
    if (expiresAt == null || expiresAt.isBefore(DateTime.now())) {
      throw const MemberSettingsException('인증번호가 만료되었습니다.');
    }

    final email = data['email']?.toString() ?? '';
    final savedHash = data['codeHash']?.toString();
    if (savedHash !=
        _verificationCodeHash(email, expectedPurpose, code.trim())) {
      throw const MemberSettingsException('인증번호가 올바르지 않습니다.');
    }

    await requestRef.set({
      'usedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));
    return data;
  }

  Future<void> _queueEmailCode({
    required String email,
    required String code,
    required String purpose,
    required DateTime expiresAt,
  }) async {
    final purposeText = switch (purpose) {
      'find_login_id' => '아이디 찾기',
      'password_reset' => '비밀번호 찾기',
      'new_device_login' => '새 기기 로그인',
      _ => '이메일 인증',
    };
    final text =
        '비비랑 우리 $purposeText 인증번호는 $code 입니다. '
        '인증번호는 ${DateFormat('HH:mm').format(expiresAt)}까지 사용할 수 있습니다.';

    try {
      await _queuePlainEmail(email: email, subject: '비비랑 우리 인증번호', text: text);
    } catch (_) {
      // 실제 메일 발송은 Firebase Trigger Email 같은 서버 구성이 필요합니다.
      // 디버그 APK에서는 호출 화면에 인증번호를 함께 보여줍니다.
    }
  }

  Future<void> _queuePlainEmail({
    required String email,
    required String subject,
    required String text,
  }) async {
    if (email.trim().isEmpty) {
      return;
    }

    try {
      await _firestore.collection('mail').add({
        'to': [email],
        'message': {'subject': subject, 'text': text},
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (_) {
      // 메일 큐 쓰기가 막혀도 회원 복구 흐름 자체는 진행합니다.
    }
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) {
      return email;
    }

    final name = parts.first;
    final domain = parts.last;
    if (name.isEmpty) {
      return email;
    }
    if (name.length <= 2) {
      return '${name[0]}***@$domain';
    }
    return '${name.substring(0, 2)}***@$domain';
  }

  String _generateTemporaryPassword() {
    const characters =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    final random = Random.secure();
    return List.generate(
      10,
      (_) => characters[random.nextInt(characters.length)],
    ).join();
  }

  String _generateCoupleCode() {
    const characters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(
      8,
      (_) => characters[random.nextInt(characters.length)],
    ).join();
  }

  Future<void> _deleteCoupleRecords() async {
    final coupleRef = _firestore.collection('couples').doc(coupleId);
    final routes = await coupleRef.collection('travel_routes').get();
    for (final route in routes.docs) {
      await _deleteQuery(route.reference.collection('comments'));
    }
    await _deleteQuery(coupleRef.collection('missions'));
    await _deleteQuery(coupleRef.collection('date_spots'));
    await _deleteQuery(coupleRef.collection('albums'));
    await _deleteQuery(coupleRef.collection('shared_locations'));
    await _deleteQuery(coupleRef.collection('travel_routes'));
  }

  Future<void> _markCoupleRecordsDisconnected() async {
    final coupleRef = _firestore.collection('couples').doc(coupleId);
    await _updateQuery(coupleRef.collection('travel_routes'), {
      'isDisconnectedCoupleRecord': true,
      'coupleDisconnectedAt': Timestamp.fromDate(DateTime.now()),
    });
    await _updateQuery(coupleRef.collection('albums'), {
      'isDisconnectedCoupleRecord': true,
      'coupleDisconnectedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> _deleteQuery(Query<Map<String, dynamic>> query) async {
    while (true) {
      final snapshot = await query.limit(400).get();
      if (snapshot.docs.isEmpty) {
        return;
      }

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (snapshot.docs.length < 400) {
        return;
      }
    }
  }

  Future<void> _updateQuery(
    Query<Map<String, dynamic>> query,
    Map<String, dynamic> data,
  ) async {
    final docs = (await query.get()).docs;
    for (var index = 0; index < docs.length; index += 400) {
      final batch = _firestore.batch();
      for (final doc in docs.skip(index).take(400)) {
        batch.set(doc.reference, data, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  // --- 공통 업로드 로직 ---
  Future<String> uploadImage(File file, String path) async {
    if (!await file.exists()) {
      throw const PhotoUploadException('Selected image file was not found.');
    }
    if (!_isCloudinaryConfigured) {
      throw const PhotoUploadException(
        'Cloudinary upload is not configured. Set CLOUDINARY_CLOUD_NAME and CLOUDINARY_UPLOAD_PRESET.',
      );
    }

    final normalizedPath = _normalizeStoragePath(path);
    final uri = Uri.https(
      'api.cloudinary.com',
      '/v1_1/$_cloudinaryCloudName/image/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _cloudinaryUploadPreset
      ..fields['folder'] = _cloudinaryFolder
      ..fields['public_id'] = _cloudinaryPublicId(normalizedPath)
      ..fields['tags'] = 'our_spring_days,$coupleId'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    try {
      final response = await request.send().timeout(
        const Duration(seconds: 45),
      );
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody) as Map<String, dynamic>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = _cloudinaryErrorMessage(data);
        throw PhotoUploadException('Cloudinary upload failed: $message');
      }

      final secureUrl = data['secure_url']?.toString();
      if (secureUrl == null || secureUrl.isEmpty) {
        throw const PhotoUploadException(
          'Cloudinary upload succeeded but no image URL was returned.',
        );
      }

      return secureUrl;
    } on PhotoUploadException {
      rethrow;
    } on TimeoutException catch (e) {
      throw PhotoUploadException('Cloudinary upload timed out.', e);
    } on FormatException catch (e) {
      throw PhotoUploadException('Cloudinary returned an invalid response.', e);
    } catch (e) {
      throw PhotoUploadException('Cloudinary upload failed: $e', e);
    }
  }

  bool get _isCloudinaryConfigured {
    return _hasRealConfigValue(_cloudinaryCloudName) &&
        _hasRealConfigValue(_cloudinaryUploadPreset);
  }

  bool _hasRealConfigValue(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isNotEmpty &&
        !normalized.startsWith('your') &&
        !normalized.contains('placeholder');
  }

  String _normalizeStoragePath(String path) {
    return path.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
  }

  String _cloudinaryPublicId(String path) {
    final withoutExtension = path.replaceFirst(RegExp(r'\.[^./]+$'), '');
    final safePath = withoutExtension
        .replaceAll(RegExp(r'[^A-Za-z0-9/_-]+'), '_')
        .replaceAll(RegExp(r'/+'), '_');
    return 'couples_${coupleId}_$safePath';
  }

  String _cloudinaryErrorMessage(Map<String, dynamic> data) {
    final error = data['error'];
    if (error is Map<String, dynamic>) {
      return error['message']?.toString() ?? data.toString();
    }
    return data.toString();
  }
}
