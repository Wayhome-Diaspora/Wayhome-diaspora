import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import 'package:bmoni_embedded_wallets_cards/bmoni_embedded_wallets_cards.dart';
import 'package:go_router/go_router.dart';

import '../config/providers.dart';

/// Home / wallet dashboard — shows the wallet card with balance.
/// Uses bkey_uikit feedback components for loading/empty/error states.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Set<String> _hiddenBalances = {};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await ref.read(walletListProvider.notifier).fetchWallets();
    final wallets = ref.read(walletListProvider).wallets;
    final ids = wallets?.map((w) => w.walletId).toList() ?? [];
    if (ids.isNotEmpty) {
      await Future.wait([
        ref.read(walletBalancesProvider.notifier).fetchWalletBalances(ids, isCache: true),
        ref.read(walletTransactionsProvider.notifier).fetchTransactionsForWallets(ids, useCache: true),
      ]);
    }
  }

  void _toggleHidden(String walletId) {
    setState(() {
      if (_hiddenBalances.contains(walletId)) {
        _hiddenBalances.remove(walletId);
      } else {
        _hiddenBalances.add(walletId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(walletListProvider);
    final balances = ref.watch(walletBalancesProvider);
    final txState = ref.watch(walletTransactionsProvider);

    final wallets = listState.wallets ?? [];
    final activeWallet = wallets.isNotEmpty ? wallets.first : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Waya'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(walletListProvider.notifier).fetchWallets(isRefresh: true);
          final ids = ref.read(walletListProvider).wallets
              ?.map((w) => w.walletId)
              .toList() ?? [];
          if (ids.isNotEmpty) {
            await ref.read(walletBalancesProvider.notifier)
                .fetchWalletBalances(ids, isCache: false);
          }
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            // Wallet card — loading state
            if (listState.isLoading && wallets.isEmpty)
              const SizedBox(
                height: 270,
                child: Center(child: ProgressLoaderWidget()),
              )
            // Wallet card — error state
            else if (listState.hasError)
              SizedBox(
                height: 270,
                child: Center(
                  child: FailureWidget(
                    message: listState.failure?.message ?? 'Failed to load wallets',
                    onRetry: () => ref.read(walletListProvider.notifier).fetchWallets(),
                  ),
                ),
              )
            // Wallet card — empty state
            else if (wallets.isEmpty)
              SizedBox(
                height: 270,
                child: Center(
                  child: EmptyState(
                    message: 'No wallets yet',
                    subtitle: 'Complete onboarding to get started',
                  ),
                ),
              )
            // Wallet card — loaded
            else
              _buildWalletCarousel(wallets, balances, listState),

            const SizedBox(height: 24),

            // Quick actions
            if (activeWallet != null) _buildQuickActions(),

            const SizedBox(height: 24),

            // Recent activity — uses EmbeddedWalletTransactionsSection
            if (activeWallet != null)
              EmbeddedWalletTransactionsSection(
                title: 'Recent activity',
                viewAllLabel: 'View all',
                onViewAll: () => context.go('/transactions'),
                transactions: txState.getTransactionsForWallet(activeWallet.walletId),
                isInitialLoading: txState.isLoading &&
                    txState.getTransactionsForWallet(activeWallet.walletId).isEmpty,
                emptyState: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: EmptyState(
                      message: 'No transactions yet',
                      subtitle: 'Send or receive money to see activity here',
                    ),
                  ),
                ),
                itemBuilder: (context, tx) => _buildTransactionRow(tx),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCarousel(
    List<EmbeddedWallet> wallets,
    Map<String, double> balances,
    EmbeddedWalletListState listState,
  ) {
    return SizedBox(
      height: 270,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.92),
        itemCount: wallets.length,
        itemBuilder: (context, index) {
          final wallet = wallets[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: EmbeddedWalletCard(
              wallet: wallet.copyWith(
                balance: balances[wallet.walletId] ?? wallet.balance,
              ),
              isBalanceHidden: _hiddenBalances.contains(wallet.walletId),
              onToggleHideBalance: () => _toggleHidden(wallet.walletId),
              isLoading: listState.isLoading,
              isRefreshing: listState.isRefreshing,
              onTap: () {},
              onInfoTap: () {},
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.add_rounded,
            label: 'Fund',
            onTap: () => context.go('/fund'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            icon: Icons.send_rounded,
            label: 'Send',
            onTap: () => context.go('/send'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            icon: Icons.arrow_downward_rounded,
            label: 'Withdraw',
            onTap: () => context.go('/withdraw'),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionRow(EmbeddedWalletTransaction tx) {
    final isPending = tx.status == EmbeddedWalletTransactionStatus.pending;
    final isFailed = tx.status == EmbeddedWalletTransactionStatus.failed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            tx.isIncoming ? Icons.south_west : Icons.north_east,
            color: tx.isIncoming ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.title ?? tx.counterpartyName ?? 'Transaction',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  tx.status.name,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isFailed
                            ? Colors.red
                            : isPending
                                ? Colors.orange
                                : Colors.white60,
                      ),
                ),
              ],
            ),
          ),
          Text(
            '${tx.isIncoming ? '+' : '-'}${tx.amount} ${tx.currency ?? ''}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tx.isIncoming ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
