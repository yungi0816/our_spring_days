import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/providers/common_providers.dart';
import '../core/providers/user_provider.dart';
import '../core/utils/translation_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  double _opacity = 0.0;
  Timer? _animationTimer;
  Timer? _navigationTimer;
  double _scale = 1.1; // 약간 큰 상태에서 시작해서 정사이즈로 줄어드는 효과

  @override
  void initState() {
    super.initState();
    // 애니메이션 시작
    _animationTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _opacity = 1.0;
          _scale = 1.0;
        });
      }
    });

    // 3초 후 로그인 상태를 확인하고 이동
    _navigationTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _navigateByLoginState();
      }
    });
  }

  Future<void> _navigateByLoginState() async {
    final userId = ref.read(currentUserProvider);
    final deviceKey = ref.read(deviceKeyProvider);
    if (userId.isEmpty) {
      if (mounted) {
        context.go('/auth');
      }
      return;
    }

    final authorized = await ref
        .read(firebaseServiceProvider)
        .isDeviceAuthorized(userId: userId, deviceKey: deviceKey);
    if (!mounted) {
      return;
    }
    if (authorized) {
      context.go('/main');
    } else {
      ref.read(currentUserProvider.notifier).signOut();
      context.go('/auth');
    }
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final String imagePath = locale.languageCode == 'ko'
        ? 'images/title_kor.png'
        : 'images/title_jp.png';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 전체 화면 이미지
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _opacity,
              duration: const Duration(seconds: 2),
              curve: Curves.easeIn,
              child: AnimatedScale(
                scale: _scale,
                duration: const Duration(seconds: 3),
                curve: Curves.easeOut,
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.cover, // 화면을 꽉 채우도록 설정
                ),
              ),
            ),
          ),
          // 하단 로딩 표시 (선택 사항)
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedOpacity(
                opacity: _opacity,
                duration: const Duration(seconds: 1),
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
