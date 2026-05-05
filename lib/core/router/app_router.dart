import 'package:go_router/go_router.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/settings/member_settings_sheet.dart';
import '../../shared/main_screen.dart';
import '../../shared/splash_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // 최초 진입 시 로딩/타이틀 화면
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    // 로그인/회원가입 화면
    GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
    // 실제 메인 앱 화면
    GoRoute(path: '/main', builder: (context, state) => const MainScreen()),
    // 회원/커플 설정 화면
    GoRoute(
      path: '/settings',
      builder: (context, state) => const MemberSettingsScreen(),
    ),
  ],
);
