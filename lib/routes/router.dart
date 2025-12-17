import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../connexion/login_page.dart';
import '../ui/OnboardingPage.dart';
import '../ui/parent/home/Home.dart';
import '../ui/prof/Home.dart';



// Vérifie si l’onboarding a déjà été vu
Future<bool> checkOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_done') ?? false;
}

// Expose a fonction that builds a GoRouter and accepts an optional Listenable
GoRouter createRouter({Listenable? refreshListenable}) {
  return GoRouter(
    initialLocation: '/onboarding',
    refreshListenable: refreshListenable,
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
        redirect: (context, state) async {
          final seen = await checkOnboarding();
          if (seen) return '/';
          return null;
        },
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/homeProf',
        builder: (context, state) => const ProfHome(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) {
          // Transmet les données passées via "extra" (ex: résultat du login)
          final extra = state.extra as Map<String, dynamic>?;
          return HomePage(
            parentData: extra,
          );
        },
      ),
    ],
  );
}
