import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/mission_provider.dart';
import '../../core/utils/translation_service.dart';
import '../record/record_screen.dart' show MissionCard;

class MissionScreen extends ConsumerWidget {
  const MissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missionsAsync = ref.watch(missionStreamProvider);
    final tr = ref.watch(translationProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: missionsAsync.when(
        data: (missions) {
          if (missions.isEmpty) {
            return Center(child: Text(tr.missionEmpty));
          }

          // 1. 통계 계산
          final total = missions.length;
          final success = missions.where((m) => m.isCompleted).length;
          final failure = missions.where((m) => m.isFailed).length;

          // 2. 날짜별 그룹화 (YYYY-MM-DD)
          final groupedMissions = <String, List<Mission>>{};
          for (var mission in missions) {
            final dateKey = DateFormat('yyyy-MM-dd').format(mission.timestamp);
            groupedMissions.putIfAbsent(dateKey, () => []).add(mission);
          }
          final sortedDates = groupedMissions.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          return Column(
            children: [
              // 통계 헤더 영역
              _buildSummaryHeader(context, tr, total, success, failure),

              // 날짜별 미션 리스트
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: sortedDates.length,
                  itemBuilder: (context, index) {
                    final date = sortedDates[index];
                    final dailyMissions = groupedMissions[date]!;
                    return _buildDateSection(context, date, dailyMissions);
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  // 요약 헤더 위젯
  Widget _buildSummaryHeader(
    BuildContext context,
    TranslationService tr,
    int total,
    int success,
    int failure,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr.missionSummary,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(tr.totalMissions, total.toString(), Colors.blue),
              _buildStatItem(tr.successCount, success.toString(), Colors.green),
              _buildStatItem(tr.failureCount, failure.toString(), Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  // 날짜 섹션 위젯
  Widget _buildDateSection(
    BuildContext context,
    String dateKey,
    List<Mission> dailyMissions,
  ) {
    // 날짜 포맷팅 (예: 2026년 04월 28일)
    final date = DateTime.parse(dateKey);
    final formattedDate = DateFormat('yyyy년 MM월 dd일').format(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.pinkAccent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formattedDate,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${dailyMissions.length}',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        ...dailyMissions.map(
          (mission) => GestureDetector(
            onTap: () => _showMissionDetail(context, mission),
            child: MissionCard(mission: mission),
          ),
        ),
      ],
    );
  }

  void _showMissionDetail(BuildContext context, Mission mission) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MissionDetailSheet(mission: mission),
    );
  }
}

class _MissionDetailSheet extends StatelessWidget {
  final Mission mission;

  const _MissionDetailSheet({required this.mission});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final status = mission.isCompleted
        ? '성공'
        : mission.isFailed
        ? '실패'
        : '진행 중';
    final statusColor = mission.isCompleted
        ? Colors.green
        : mission.isFailed
        ? Colors.redAccent
        : Colors.pinkAccent;
    final proofUrl = mission.proofImageUrl;
    final originalUrl = mission.originalImageUrl;

    return Container(
      height: size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Chip(
                  label: Text(status),
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  labelStyle: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  mission.content,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  [
                    '제안자 ${mission.creatorId}',
                    if (mission.winnerId != null) '도전자 ${mission.winnerId}',
                    DateFormat('yyyy.MM.dd HH:mm').format(mission.timestamp),
                  ].join(' / '),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                if (proofUrl != null) ...[
                  const Text(
                    '인증 사진',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _MissionImage(url: proofUrl),
                  const SizedBox(height: 16),
                ],
                if (originalUrl != null) ...[
                  const Text(
                    '제안 사진',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _MissionImage(url: originalUrl),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionImage extends StatelessWidget {
  final String url;

  const _MissionImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: Colors.grey[100],
        constraints: const BoxConstraints(minHeight: 180, maxHeight: 420),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) =>
              const SizedBox(height: 220, child: Icon(Icons.broken_image)),
        ),
      ),
    );
  }
}
