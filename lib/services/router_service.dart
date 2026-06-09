import 'package:go_router/go_router.dart';
import '../features/onboarding/splash_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/dashboard/main_shell.dart';
import '../features/auth/auth_screen.dart';
import '../features/vision_lens/vision_lens/screens/vision_lens_home_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
    GoRoute(path: '/home', builder: (context, state) => const MainShell()),
    GoRoute(
      path: '/vision_lens',
      builder: (context, state) => const VisionLensHomeScreen(),
    ),
  ],
);

