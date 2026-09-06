import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import 'package:bmoni_embedded_wallets_cards/bmoni_embedded_wallets_cards.dart';

import '../config/providers.dart';

/// Transaction history screen — filterable by type.
/// Uses bkey_uikit feedback components (EmptyState, FailureWidget, InProgressWidget).
class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  String _filter = 'all'; // all, funded, sent, received, withdrawn

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final wallets = ref.read(walletListProvider).wallets ?? [];
    final ids = wallets.map((w) => w.walletId).toList();
    if (ids.isNotEmpty) {
      await ref
          .read(walletTransactionsProvider.notifier)
          .fetchTransactionsForWallets(ids, useCache: false);
    }
  }

  List<EmbeddedWalletTransaction> _filterTransactions(
    List<EmbeddedWalletTransaction> transactions,
  ) {
    switch (_filter) {
      case 'sent':
        return transactions
            .where((t) => !t.isIncoming && t.status != EmbeddedWalletTransactionStatus.pending)
            .toList();
      case 'received':
        return transactions
            .where((t) => t.isIncoming && t.status != EmbeddedWalletTransactionStatus.pending)
            .toList();
      case 'funded':
        return transactions
            .where((t) => t.isIncoming && t.title?.toLowerCase().contains('fund') == true)
            .toList();
      case 'withdrawn':
        return transactions
            .where((t) => !t.isIncoming && t.title?.toLowerCase().contains('withdraw') == true)
            .toList();
      default:
        return transactions;
    }
  }

  @override
  Widget build(BuildContext context) {
    final txState = ref.watch(walletTransactionsProvider);
    final wallets = ref.watch(walletListProvider).wallets ?? [];
    final activeWallet = wallets.isNotEmpty ? wallets.first : null;

    final allTransactions = activeWallet != null
        ? txState.getTransactionsForWallet(activeWallet.walletId)
        : <EmbeddedWalletTransaction>[];
    final filteredTransactions = _filterTransactions(allTransactions);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter chips
          _buildFilterChips(),
          const SizedBox(height: 8),
          // Content
          Expanded(child: _buildContent(txState, filteredTransactions)),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      ('all', 'All'),
      ('funded', 'Funded'),
      ('sent', 'Sent'),
      ('received', 'Received'),
      ('withdrawn', 'Withdrawn'),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (value, label) = filters[index];
          final isSelected = _filter == value;
          return FilterChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (_) => setState(() => _filter = value),
            selectedColor: Colors.white,
            backgroundColor: Colors.white.withAlpha(15),
            labelStyle: TextStyle(
              color: isSelected ? Colors.black : Colors.white70,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
            side: BorderSide(
              color: isSelected ? Colors.white : Colors.white24,
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(
    EmbeddedWalletTransactionsState txState,
    List<EmbeddedWalletTransaction> transactions,
  ) {
    // Loading state
    if (txState.isLoading && transactions.isEmpty) {
      return const Center(
        child: InProgressWidget(message: 'Loading transactions...'),
      );
    }

    // Error state
    if (txState.hasError) {
      return Center(
        child: FailureWidget(
          message: txState.failure?.message ?? 'Failed to load transactions',
          onRetry: _loadTransactions,
        ),
      );
    }

    // Empty state
    if (transactions.isEmpty) {
      return Center(
        child: EmptyState(
          message: _emptyTitle,
          subtitle: _emptySubtitle,
        ),
      );
    }

    // Transaction list
    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: transactions.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
        itemBuilder: (context, index) {
          final tx = transactions[index];
          return _buildTransactionTile(tx);
        },
      ),
    );
  }

  String get _emptyTitle {
    switch (_filter) {
      case 'sent':
        return 'No sent transactions';
      case 'received':
        return 'No received transactions';
      case 'funded':
        return 'No funded transactions';
      case 'withdrawn':
        return 'No withdrawals';
      default:
        return 'No transactions yet';
    }
  }

  String? get _emptySubtitle {
    switch (_filter) {
      case 'sent':
        return 'Send money to see transactions here';
      case 'received':
        return 'Receive money to see transactions here';
      case 'funded':
        return 'Fund your wallet to get started';
      case 'withdrawn':
        return 'Withdraw to a bank account to see transactions here';
      default:
        return 'Your transaction history will appear here';
    }
  }

  Widget _buildTransactionTile(EmbeddedWalletTransaction tx) {
    final isPending = tx.status == EmbeddedWalletTransactionStatus.pending;
    final isFailed = tx.status == EmbeddedWalletTransactionStatus.failed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Direction icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tx.isIncoming
                  ? Colors.green.withAlpha(20)
                  : Colors.red.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              tx.isIncoming ? Icons.south_west : Icons.north_east,
              color: tx.isIncoming ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.title ?? tx.counterpartyName ?? 'Transaction',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  _statusLabel(tx.status),
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
          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${tx.isIncoming ? '+' : '-'}${tx.amount.toStringAsFixed(2)} ${tx.currency ?? ''}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tx.isIncoming ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (tx.createdAt != null)
                Text(
                  _formatDate(tx.createdAt!),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white38,
                      ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(EmbeddedWalletTransactionStatus status) {
    switch (status) {
      case EmbeddedWalletTransactionStatus.pending:
        return 'Pending';
      case EmbeddedWalletTransactionStatus.completed:
        return 'Completed';
      case EmbeddedWalletTransactionStatus.failed:
        return 'Failed';
      case EmbeddedWalletTransactionStatus.reversed:
        return 'Reversed';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
