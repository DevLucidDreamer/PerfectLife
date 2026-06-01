import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'fonts.dart';
import 'onboarding/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));

  final store = Store();
  await store.init();

  runApp(
    ChangeNotifierProvider.value(value: store, child: const GatsaengApp()),
  );
}

class GatsaengApp extends StatelessWidget {
  const GatsaengApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '오늘부터 갓생',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.dark,
          surface: AppColors.bg,
        ),
        textTheme: TextTheme(
          bodyMedium: AppFonts.sans(size: 14, color: AppColors.ink, height: 1.5),
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      home: const _RootGate(),
    );
  }
}

/// 첫 실행(백지 + 프로필 없음)이면 온보딩을, 아니면 홈을 보여준다.
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final needsOnboarding = context.select<Store, bool>((s) => s.needsOnboarding);
    return needsOnboarding ? const OnboardingScreen() : const HomeScreen();
  }
}
