import 'package:dartz/dartz.dart';
import 'package:bmoni_embedded_wallets_cards/bmoni_embedded_wallets_cards.dart';

import 'api_service.dart';

/// Implements EmbeddedWalletReadDataSource against the Waya backend BFF.
/// The backend proxies all BMONI API calls — the secret key never touches the client.
class WayaWalletDataSource implements EmbeddedWalletReadDataSource {
  @override
  Future<Either<EmbeddedFailure, EmbeddedWalletListResponse>> fetchWallets() async {
    try {
      final userId = await ApiService.getStoredUserId();
      if (userId == null) {
        return Left(EmbeddedAuthenticationFailure(message: 'No user session'));
      }

      final data = await ApiService.get('/users/$userId/smart-wallets/account/wallets');
      final wallets = (data['wallets'] as List?)
              ?.map((w) => EmbeddedWallet(
                    walletId: w['id'] ?? w['walletId'] ?? '',
                    name: w['name'] ?? w['currency'] ?? 'Wallet',
                    currency: w['currency'] ?? 'USD',
                    balance: (w['balance'] as num?)?.toDouble() ?? 0.0,
                    colorSuffix: w['colorSuffix'],
                  ))
              .toList() ??
          [];

      return Right(EmbeddedWalletListResponse(wallets: wallets));
    } catch (e) {
      return Left(EmbeddedServerFailure(message: 'Failed to fetch wallets: $e'));
    }
  }

  @override
  Future<Either<EmbeddedFailure, EmbeddedWalletDetailResponse>> fetchWalletDetail(
    String walletId,
  ) async {
    try {
      final userId = await ApiService.getStoredUserId();
      if (userId == null) {
        return Left(EmbeddedAuthenticationFailure(message: 'No user session'));
      }

      final data = await ApiService.get('/users/$userId/smart-wallets/$walletId');
      final wallet = EmbeddedWallet(
        walletId: data['id'] ?? walletId,
        name: data['name'] ?? data['currency'] ?? 'Wallet',
        currency: data['currency'] ?? 'USD',
        balance: (data['balance'] as num?)?.toDouble() ?? 0.0,
        colorSuffix: data['colorSuffix'],
      );

      return Right(EmbeddedWalletDetailResponse(wallet: wallet));
    } catch (e) {
      return Left(EmbeddedServerFailure(message: 'Failed to fetch wallet detail: $e'));
    }
  }

  @override
  Future<Either<EmbeddedFailure, EmbeddedWalletBalanceResponse>> fetchBalance(
    String walletId,
  ) async {
    try {
      final userId = await ApiService.getStoredUserId();
      if (userId == null) {
        return Left(EmbeddedAuthenticationFailure(message: 'No user session'));
      }

      final data = await ApiService.get('/users/$userId/smart-wallets/account/balances');
      final balances = data['balances'] as Map<String, dynamic>? ?? {};
      final balance = balances[walletId]?.toDouble() ?? 0.0;

      return Right(EmbeddedWalletBalanceResponse(walletId: walletId, balance: balance));
    } catch (e) {
      return Left(EmbeddedServerFailure(message: 'Failed to fetch balance: $e'));
    }
  }

  @override
  Future<Either<EmbeddedFailure, EmbeddedWalletTransactionsResponse>> fetchTransactions(
    String walletId, {
    int? page,
    int? pageSize,
  }) async {
    try {
      final userId = await ApiService.getStoredUserId();
      if (userId == null) {
        return Left(EmbeddedAuthenticationFailure(message: 'No user session'));
      }

      // Fetch proposal history (transfers, swaps, offramps)
      final data = await ApiService.get(
        '/users/$userId/smart-wallets/$walletId/proposals',
      );

      final proposals = (data['data'] as List?) ?? (data['proposals'] as List?) ?? [];
      final transactions = proposals.map<EmbeddedWalletTransaction>((p) {
        final status = p['status'] ?? 'unknown';
        final type = p['type'] ?? 'TRANSFER';
        final amount = double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
        final currency = p['currency'] ?? 'NGN';
        final createdAt = p['createdAt'] != null
            ? DateTime.tryParse(p['createdAt'])
            : null;

        // Determine direction based on type and fields
        final isIncoming = type == 'SWAP' && p['toStablecoin'] != null;

        return EmbeddedWalletTransaction(
          id: p['id'] ?? '',
          walletId: walletId,
          amount: amount,
          currency: currency,
          direction: isIncoming
              ? EmbeddedTransactionDirection.incoming
              : EmbeddedTransactionDirection.outgoing,
          status: _mapStatus(status),
          title: _transactionTitle(type, status),
          counterpartyName: p['description'] ?? p['toUserId'],
          createdAt: createdAt,
        );
      }).toList();

      return Right(EmbeddedWalletTransactionsResponse(transactions: transactions));
    } catch (e) {
      return Left(EmbeddedServerFailure(message: 'Failed to fetch transactions: $e'));
    }
  }

  EmbeddedWalletTransactionStatus _mapStatus(String status) {
    switch (status) {
      case 'COMPLETED':
        return EmbeddedWalletTransactionStatus.completed;
      case 'FAILED':
        return EmbeddedWalletTransactionStatus.failed;
      case 'PENDING_APPROVALS':
      case 'PENDING_SIGNATURES':
        return EmbeddedWalletTransactionStatus.pending;
      default:
        return EmbeddedWalletTransactionStatus.pending;
    }
  }

  String _transactionTitle(String type, String status) {
    switch (type) {
      case 'TRANSFER':
        return status == 'COMPLETED' ? 'Money sent' : 'Sending...';
      case 'SWAP':
        return status == 'COMPLETED' ? 'Currency converted' : 'Converting...';
      default:
        return 'Transaction';
    }
  }
}
