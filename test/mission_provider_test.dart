import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:our_spring_days/core/constants/app_constants.dart';
import 'package:our_spring_days/core/providers/mission_provider.dart';

void main() {
  test('MissionNotifier allows multiple ongoing missions', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(missionProvider.notifier);

    final first = Mission(
      id: 'first',
      content: '첫 번째 미션',
      creatorId: AppConstants.partnerAId,
      timestamp: DateTime(2026),
      deadline: DateTime(2026, 1, 2),
    );
    final second = Mission(
      id: 'second',
      content: '두 번째 미션',
      creatorId: AppConstants.partnerBId,
      timestamp: DateTime(2026),
      deadline: DateTime(2026, 1, 3),
    );

    notifier.addMission(first);
    notifier.addMission(second);

    final missions = container.read(missionProvider);
    expect(missions, hasLength(2));
    expect(missions.map((mission) => mission.id), ['second', 'first']);
  });
}
