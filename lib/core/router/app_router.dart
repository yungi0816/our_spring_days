import 'package:go_router/go_router.dart';
import '../../shared/main_screen.dart';
import '../../shared/splash_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // 최초 진입 시 로딩/타이틀 화면
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    // 실제 메인 앱 화면
    GoRoute(path: '/main', builder: (context, state) => const MainScreen()),
  ],
);
