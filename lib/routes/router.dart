import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../connexion/login_page.dart';
import '../ui/OnboardingPage.dart';
import '../ui/parent/Home.dart';

// Vérifie si l’onboarding a déjà été vu
Future<bool> checkOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_done') ?? false;
}

final GoRouter router = GoRouter(
  initialLocation: '/onboarding',
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingPage(),
      redirect: (context, state) async {
        final seen = await checkOnboarding();
        if (seen) return '/home';
        return null;
      },
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => HomePage(
          //username: state.extra as String
      )
    ),
  ],
);
