import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'common_providers.dart';

// 미션 모델
class Mission {
  static const _unset = Object();

  final String id;
  final String content;
  final String? originalImagePath;
  final String? originalImageUrl;
  final String? proofImagePath;
  final String? proofImageUrl;
  final bool isCompleted;
  final bool isJoint;
  final String? winnerId;
  final String creatorId;
  final DateTime timestamp;
  final DateTime? deadline;
  final DateTime? completedAt;

  Mission({
    required this.id,
    required this.content,
    this.originalImagePath,
    this.originalImageUrl,
    this.proofImagePath,
    this.proofImageUrl,
    this.isCompleted = false,
    this.isJoint = false,
    this.winnerId,
    required this.creatorId,
    required this.timestamp,
    this.deadline,
    this.completedAt,
  });

  bool get isFailed =>
      !isCompleted && deadline != null && DateTime.now().isAfter(deadline!);

  factory Mission.fromMap(Map<String, dynamic> map, String id) {
    final timestamp = map['timestamp'];
    final deadline = map['deadline'];
    final completedAt = map['completedAt'];

    return Mission(
      id: id,
      content: map['content'] ?? '',
      originalImagePath: map['originalImagePath'],
      originalImageUrl: map['originalImageUrl'],
      proofImagePath: map['proofImagePath'],
      proofImageUrl: map['proofImageUrl'],
      isCompleted: map['isCompleted'] ?? false,
      isJoint: map['isJoint'] ?? false,
      winnerId: map['winnerId'],
      creatorId: map['creatorId'] ?? '',
      timestamp: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      deadline: deadline is Timestamp ? deadline.toDate() : null,
      completedAt: completedAt is Timestamp ? completedAt.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'originalImagePath': originalImagePath,
      'originalImageUrl': originalImageUrl,
      'proofImagePath': proofImagePath,
      'proofImageUrl': proofImageUrl,
      'isCompleted': isCompleted,
      'isJoint': isJoint,
      'winnerId': winnerId,
      'creatorId': creatorId,
      'timestamp': Timestamp.fromDate(timestamp),
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
    };
  }

  Mission copyWith({
    String? content,
    String? originalImagePath,
    String? originalImageUrl,
    String? proofImagePath,
    String? proofImageUrl,
    bool? isCompleted,
    bool? isJoint,
    String? winnerId,
    Object? deadline = _unset,
    Object? completedAt = _unset,
  }) {
    return Mission(
      id: id,
      content: content ?? this.content,
      originalImagePath: originalImagePath ?? this.originalImagePath,
      originalImageUrl: originalImageUrl ?? this.originalImageUrl,
      proofImagePath: proofImagePath ?? this.proofImagePath,
      proofImageUrl: proofImageUrl ?? this.proofImageUrl,
      isCompleted: isCompleted ?? this.isCompleted,
      isJoint: isJoint ?? this.isJoint,
      winnerId: winnerId ?? this.winnerId,
      creatorId: creatorId,
      timestamp: timestamp,
      deadline: identical(deadline, _unset)
          ? this.deadline
          : deadline as DateTime?,
      completedAt: identical(completedAt, _unset)
          ? this.completedAt
          : completedAt as DateTime?,
    );
  }
}

// -----------------------------------------------------------------------------
// Firebase 연동을 위한 Provider 설정
// -----------------------------------------------------------------------------

// 1. 미션 리스트 실시간 스트림 Provider
final missionStreamProvider = StreamProvider<List<Mission>>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return firebaseService.getMissionStream();
});

class MissionNotifier extends Notifier<List<Mission>> {
  @override
  List<Mission> build() => const [];

  void addMission(Mission mission) {
    state = [mission, ...state];
  }

  void updateMission(String id, String content) {
    state = [
      for (final mission in state)
        if (mission.id == id) mission.copyWith(content: content) else mission,
    ];
  }

  void completeMission(String id, String proofImagePath, String winnerId) {
    state = [
      for (final mission in state)
        if (mission.id == id)
          mission.copyWith(
            proofImagePath: proofImagePath,
            isCompleted: true,
            winnerId: winnerId,
            completedAt: DateTime.now(),
          )
        else
          mission,
    ];
  }

  void deleteMission(String id) {
    state = [
      for (final mission in state)
        if (mission.id != id) mission,
    ];
  }
}

final missionProvider = NotifierProvider<MissionNotifier, List<Mission>>(
  MissionNotifier.new,
);
