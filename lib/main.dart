import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io' show Platform;
import 'package:shared_preferences/shared_preferences.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/common_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // SharedPreferences 초기화
  final prefs = await SharedPreferences.getInstance();

  // Firebase 초기화
  try {
    if (kIsWeb) {
      // 웹 대응이 필요한 경우 여기에 설정 추가
      await Firebase.initializeApp();
    } else {
      if (Platform.isAndroid) {
        final options = _androidFirebaseOptionsFromEnvironment();
        if (options == null) {
          await Firebase.initializeApp();
        } else {
          await Firebase.initializeApp(options: options);
        }
      } else if (Platform.isIOS) {
        // iOS는 GoogleService-Info.plist를 추가한 후 아래와 같이 호출하거나,
        // 나중에 명시적인 options를 추가하여 대응 가능합니다.
        await Firebase.initializeApp();
      } else {
        await Firebase.initializeApp();
      }
    }
  } catch (e) {
    debugPrint('Firebase 초기화 에러: $e');
  }

  await _ensureFirebaseAuthSession();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const OurSpringApp(),
    ),
  );
}

Future<void> _ensureFirebaseAuthSession() async {
  try {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
  } catch (e) {
    debugPrint('Firebase 익명 인증 에러: $e');
  }
}

class OurSpringApp extends StatelessWidget {
  const OurSpringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '비비랑 우리',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko'), Locale('ja')],
    );
  }
}

FirebaseOptions? _androidFirebaseOptionsFromEnvironment() {
  const apiKey = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  const appId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  const messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

  if (apiKey.isEmpty ||
      appId.isEmpty ||
      messagingSenderId.isEmpty ||
      projectId.isEmpty) {
    return null;
  }

  return const FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    storageBucket: storageBucket,
  );
}
