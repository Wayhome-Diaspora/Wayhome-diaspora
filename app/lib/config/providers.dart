import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bmoni_embedded_wallets_cards/bmoni_embedded_wallets_cards.dart';

import '../services/wallet_data_source.dart';

/// Data source provider — implements the BMONI wallet read contracts
/// against our backend BFF.
final walletDataSourceProvider = Provider<EmbeddedWalletReadDataSource>((ref) {
  return WayaWalletDataSource();
});

/// In-memory wallet storage (for Phase 1; replace with persistent storage later).
class InMemoryWalletStorage implements EmbeddedWalletStorage {
  final Map<String, List<EmbeddedWallet>> _wallets = {};
  final Map<String, List<EmbeddedWalletTransaction>> _txs = {};

  @override
  Future<void> saveWallets(List<EmbeddedWallet> wallets) async =>
      _wallets['wallets'] = wallets;

  @override
  Future<List<EmbeddedWallet>?> loadWallets() async => _wallets['wallets'];

  @override
  Future<void> saveTransactions(
    String walletId,
    List<EmbeddedWalletTransaction> transactions,
  ) async => _txs[walletId] = transactions;

  @override
  Future<List<EmbeddedWalletTransaction>?> loadTransactions(String walletId) async =>
      _txs[walletId];
}

final walletStorageProvider = Provider<EmbeddedWalletStorage>((ref) {
  return InMemoryWalletStorage();
});

/// In-memory balance cache.
class InMemoryBalanceCache implements EmbeddedWalletBalanceCache {
  final Map<String, double> _balances = {};

  @override
  Future<void> saveBalance(String walletId, double balance) async =>
      _balances[walletId] = balance;

  @override
  Future<double?> loadBalance(String walletId) async => _balances[walletId];

  @override
  Future<void> clearAll() async => _balances.clear();
}

final walletBalanceCacheProvider = Provider<EmbeddedWalletBalanceCache>((ref) {
  return InMemoryBalanceCache();
});

/// Wallet list notifier provider.
final walletListProvider =
    StateNotifierProvider<EmbeddedWalletListNotifier, EmbeddedWalletListState>(
  (ref) => EmbeddedWalletListNotifier(
    walletDataSource: ref.watch(walletDataSourceProvider),
    storage: ref.watch(walletStorageProvider),
  ),
);

/// Wallet balances notifier provider.
final walletBalancesProvider =
    StateNotifierProvider<EmbeddedWalletBalanceNotifier, Map<String, double>>(
  (ref) => EmbeddedWalletBalanceNotifier(
    walletDataSource: ref.watch(walletDataSourceProvider),
    cache: ref.watch(walletBalanceCacheProvider),
  ),
);

/// Wallet transactions notifier provider.
final walletTransactionsProvider = StateNotifierProvider<
    EmbeddedWalletTransactionsNotifier, EmbeddedWalletTransactionsState>(
  (ref) => EmbeddedWalletTransactionsNotifier(
    walletDataSource: ref.watch(walletDataSourceProvider),
    storage: ref.watch(walletStorageProvider),
  ),
);
