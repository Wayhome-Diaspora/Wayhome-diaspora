import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/kyc_screen.dart';
import '../screens/home_screen.dart';
import '../screens/send_money_screen.dart';
import '../screens/fund_wallet_screen.dart';
import '../screens/withdraw_screen.dart';
import '../screens/transaction_history_screen.dart';
import '../screens/settings_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) {
          final role = state.uri.queryParameters['role'] ?? 'sender';
          return OnboardingScreen(role: role);
        },
      ),
      GoRoute(
        path: '/kyc',
        builder: (context, state) {
          final role = state.uri.queryParameters['role'] ?? 'sender';
          return KycScreen(role: role);
        },
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/send',
        builder: (context, state) => const SendMoneyScreen(),
      ),
      GoRoute(
        path: '/fund',
        builder: (context, state) => const FundWalletScreen(),
      ),
      GoRoute(
        path: '/withdraw',
        builder: (context, state) => const WithdrawScreen(),
      ),
      GoRoute(
        path: '/transactions',
        builder: (context, state) => const TransactionHistoryScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
