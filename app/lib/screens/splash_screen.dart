import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/wallet_service.dart';

/// Splash screen — checks for existing wallet and routes accordingly.
/// If wallet exists → home. Otherwise → role selection → onboarding.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkWallet();
  }

  Future<void> _checkWallet() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final hasWallet = await WalletService.hasWallet();
    if (!mounted) return;

    if (hasWallet) {
      context.go('/home');
    } else {
      setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: _checking ? _buildLoadingState() : _buildRoleSelection(context),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildRoleSelection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Text(
            'Waya',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send money home, instantly.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const Spacer(flex: 2),
          _RoleCard(
            title: 'Sending money?',
            subtitle: 'I\'m in the diaspora',
            icon: Icons.send_rounded,
            onTap: () => context.go('/onboarding?role=sender'),
          ),
          const SizedBox(height: 16),
          _RoleCard(
            title: 'Receiving money?',
            subtitle: 'I\'m in Nigeria',
            icon: Icons.account_balance_wallet_rounded,
            onTap: () => context.go('/onboarding?role=recipient'),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(30)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white60,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
