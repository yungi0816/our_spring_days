import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../features/record/record_screen.dart';
import '../features/map/map_screen.dart';
import '../features/mission/mission_screen.dart';
import '../features/album/album_screen.dart';
import '../features/route/route_screen.dart';
import '../core/utils/translation_service.dart';
import '../core/providers/user_provider.dart';
import '../core/providers/user_profile_provider.dart';
import '../core/providers/common_providers.dart';

// 현재 선택된 탭 인덱스를 관리하는 Notifier 및 Provider
class BottomNavNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    state = index;
  }
}

final bottomNavIndexProvider = NotifierProvider<BottomNavNotifier, int>(
  BottomNavNotifier.new,
);

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  Future<void> _changeProfileImage(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final firebaseService = ref.read(firebaseServiceProvider);
      final file = File(image.path);

      try {
        // Upload to Storage
        final url = await firebaseService.uploadImage(
          file,
          'profiles/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg',
        );

        // Update Firestore
        await firebaseService.updateUserProfile(userId, {'photoUrl': url});

        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('프로필 사진이 변경되었습니다.')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('업로드 실패: $e')));
        }
      }
    }
  }

  Future<void> _resetProfileImage(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    try {
      await ref.read(firebaseServiceProvider).resetUserProfilePhoto(userId);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('기본 이미지로 변경되었습니다.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('초기화 실패: $e')));
      }
    }
  }

  void _showProfileDialog(
    BuildContext context,
    WidgetRef ref,
    String? url,
    String userId,
  ) {
    final tr = ref.read(translationProvider);
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: url != null
                  ? Image.network(
                      url,
                      key: ValueKey(url),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Image.asset(
                        _defaultProfileAsset(userId),
                        fit: BoxFit.contain,
                      ),
                    )
                  : Image.asset(
                      _defaultProfileAsset(userId),
                      fit: BoxFit.contain,
                    ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    await _changeProfileImage(context, ref, userId);
                  },
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: Text(tr.changePhoto),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    await _resetProfileImage(context, ref, userId);
                  },
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: Text(tr.resetDefaultImage),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(tr.close),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rawSelectedIndex = ref.watch(bottomNavIndexProvider);
    final tr = ref.watch(translationProvider);
    final currentUser = ref.watch(currentUserProvider);
    final userProfileAsync = ref.watch(userProfileProvider(currentUser));

    final List<Widget> screens = [
      const RecordScreen(),
      const MapScreen(),
      const MissionScreen(),
      const AlbumScreen(),
      const RouteScreen(),
    ];
    final selectedIndex = rawSelectedIndex >= screens.length
        ? 0
        : rawSelectedIndex;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          tr.appName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: userProfileAsync.when(
          data: (profile) => GestureDetector(
            onTap: () =>
                _showProfileDialog(context, ref, profile.photoUrl, currentUser),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipOval(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: profile.photoUrl != null
                      ? Image.network(
                          profile.photoUrl!,
                          key: ValueKey(profile.photoUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Image.asset(
                                _defaultProfileAsset(currentUser),
                                fit: BoxFit.cover,
                              ),
                        )
                      : Image.asset(
                          _defaultProfileAsset(currentUser),
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ),
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(12.0),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          error: (error, stackTrace) => const Icon(Icons.error),
        ),
        actions: [
          // 사용자 전환 버튼
          SizedBox(
            width: 86,
            child: TextButton(
              onPressed: () {
                final newUser = otherPartnerId(currentUser);
                ref.read(currentUserProvider.notifier).setUser(newUser);
              },
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  currentUser,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.pinkAccent,
                  ),
                ),
              ),
            ),
          ),
          // 언어 변경 토글
          SizedBox(
            width: 48,
            child: IconButton(
              icon: const Icon(Icons.language, size: 22),
              onPressed: () {
                final currentLocale = ref.read(localeProvider);
                final newLocale = currentLocale.languageCode == 'ko'
                    ? const Locale('ja')
                    : const Locale('ko');
                ref.read(localeProvider.notifier).setLocale(newLocale);
              },
            ),
          ),
        ],
      ),
      body: IndexedStack(index: selectedIndex, children: screens),
      bottomNavigationBar: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: selectedIndex,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          iconSize: 22,
          onTap: (index) {
            ref.read(bottomNavIndexProvider.notifier).setIndex(index);
          },
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.favorite_border),
              activeIcon: const Icon(Icons.favorite),
              label: tr.tabRecord,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.map_outlined),
              activeIcon: const Icon(Icons.map),
              label: tr.tabMap,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.assignment_outlined),
              activeIcon: const Icon(Icons.assignment),
              label: tr.tabMission,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.photo_library_outlined),
              activeIcon: const Icon(Icons.photo_library),
              label: tr.tabAlbum,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.route_outlined),
              activeIcon: const Icon(Icons.route),
              label: tr.tabRoute,
            ),
          ],
        ),
      ),
    );
  }

  String _defaultProfileAsset(String userId) {
    return isPartnerAUser(userId) ? 'images/girl.png' : 'images/boy.png';
  }
}
