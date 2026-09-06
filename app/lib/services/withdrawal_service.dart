import 'package:bmoni_embedded_sdk/bmoni_embedded_sdk.dart';
import 'api_service.dart';

/// Withdrawal service — handles the full NGN withdrawal flow:
/// verify bank account → register → create offramp → sign.
class WithdrawalService {
  /// List supported Nigerian banks.
  static Future<List<dynamic>> getNigerianBanks() async {
    final userId = await ApiService.getStoredUserId();
    final result = await ApiService.get('/users/$userId/bank-accounts/nigerian-banks');
    return (result['banks'] as List?) ?? [];
  }

  /// Verify a Nigerian bank account number.
  /// Returns the account holder name.
  static Future<Map<String, dynamic>> verifyAccount({
    required String accountNumber,
    required String bankCode,
  }) async {
    final userId = await ApiService.getStoredUserId();
    return ApiService.post(
      '/users/$userId/bank-accounts/verify-nigerian-account',
      body: {
        'accountNumber': accountNumber,
        'bankCode': bankCode,
      },
    );
  }

  /// Register a withdrawal account.
  static Future<Map<String, dynamic>> registerAccount({
    required String accountNumber,
    required String bankCode,
    required String bankName,
    required String accountHolderName,
  }) async {
    final userId = await ApiService.getStoredUserId();
    return ApiService.post(
      '/users/$userId/bank-accounts/withdrawal-accounts/nigeria',
      body: {
        'accountNumber': accountNumber,
        'bankCode': bankCode,
        'bankName': bankName,
        'accountHolderName': accountHolderName,
      },
    );
  }

  /// Create an offramp proposal (NGN bank withdrawal).
  static Future<Map<String, dynamic>> createOfframp({
    required String smartWalletId,
    required String bankAccountId,
    required String fromAmount,
  }) async {
    final userId = await ApiService.getStoredUserId();
    return ApiService.post(
      '/users/$userId/smart-wallets/$smartWalletId/offramp/nigeria',
      body: {
        'bankAccountId': bankAccountId,
        'fromAmount': fromAmount,
      },
    );
  }

  /// Sign an offramp proposal on-device.
  static Future<String> signOfframpOnDevice({
    required String hashToSign,
    required String pin,
  }) async {
    return BmoniEmbeddedSdk.signTransactionHash(hashToSign, pin: pin);
  }

  /// Full withdrawal flow: verify → register → offramp → sign.
  static Future<Map<String, dynamic>> withdraw({
    required String smartWalletId,
    required String accountNumber,
    required String bankCode,
    required String bankName,
    required String fromAmount,
    required String pin,
  }) async {
    // 1. Verify account
    final verification = await verifyAccount(
      accountNumber: accountNumber,
      bankCode: bankCode,
    );
    final accountHolderName = verification['accountHolderName'] ?? verification['name'];

    // 2. Register account
    final registration = await registerAccount(
      accountNumber: accountNumber,
      bankCode: bankCode,
      bankName: bankName,
      accountHolderName: accountHolderName,
    );
    final bankAccountId = registration['id'];

    // 3. Create offramp proposal
    final offramp = await createOfframp(
      smartWalletId: smartWalletId,
      bankAccountId: bankAccountId,
      fromAmount: fromAmount,
    );

    final proposalId = offramp['data']?['proposalId'] ?? offramp['proposalId'];
    if (proposalId == null) {
      throw Exception('No proposal ID returned from offramp');
    }

    // 4. Wait for PENDING_SIGNATURES
    Map<String, dynamic>? signPayload;
    for (var i = 0; i < 10; i++) {
      await Future.delayed(const Duration(seconds: 1));
      final userId = await ApiService.getStoredUserId();
      final status = await ApiService.get('/users/$userId/smart-wallets/proposals/$proposalId');
      final proposalStatus = status['data']?['proposal']?['status'] ?? status['status'];
      if (proposalStatus == 'PENDING_SIGNATURES') {
        signPayload = await ApiService.get('/users/$userId/smart-wallets/proposals/$proposalId/sign-payload');
        break;
      }
      if (proposalStatus == 'COMPLETED') {
        return status;
      }
    }

    if (signPayload == null) {
      throw Exception('Offramp proposal did not reach PENDING_SIGNATURES');
    }

    final hashToSign = signPayload['data']?['hashToSign'] ?? signPayload['hashToSign'];

    // 5. Sign on device
    final signature = await signOfframpOnDevice(hashToSign: hashToSign, pin: pin);

    // 6. Submit signature
    final userId = await ApiService.getStoredUserId();
    await ApiService.post(
      '/users/$userId/smart-wallets/proposals/$proposalId/sign',
      body: {'signature': signature},
    );

    // 7. Poll for completion
    for (var i = 0; i < 10; i++) {
      await Future.delayed(const Duration(seconds: 1));
      final status = await ApiService.get('/users/$userId/smart-wallets/proposals/$proposalId');
      final proposalStatus = status['data']?['proposal']?['status'] ?? status['status'];
      if (proposalStatus == 'COMPLETED' || proposalStatus == 'FAILED') {
        return status;
      }
    }

    return {'status': 'PENDING_SIGNATURES', 'proposalId': proposalId};
  }
}
