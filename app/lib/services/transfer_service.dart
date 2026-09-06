import 'package:bmoni_embedded_sdk/bmoni_embedded_sdk.dart';
import 'api_service.dart';

/// Transfer service — handles the full send flow:
/// create proposal → approve → sign → submit.
class TransferService {
  /// Create a transfer proposal (server picks the wallet).
  static Future<Map<String, dynamic>> createProposal({
    required String recipientUserId,
    required String amount,
    required String currency,
    String? description,
  }) async {
    final userId = await ApiService.getStoredUserId();
    return ApiService.post('/users/$userId/smart-wallets/account/send', body: {
      'toUserId': recipientUserId,
      'amount': amount,
      'currency': currency,
      if (description != null) 'note': description,
    });
  }

  /// Approve a proposal.
  static Future<Map<String, dynamic>> approveProposal(String proposalId) async {
    final userId = await ApiService.getStoredUserId();
    return ApiService.post('/users/$userId/smart-wallets/proposals/$proposalId/approve');
  }

  /// Get the signing payload for a proposal.
  static Future<Map<String, dynamic>> getSignPayload(String proposalId) async {
    final userId = await ApiService.getStoredUserId();
    return ApiService.get('/users/$userId/smart-wallets/proposals/$proposalId/sign-payload');
  }

  /// Sign a proposal on-device using the SDK.
  /// Returns the hex signature.
  static Future<String> signProposalOnDevice({
    required String hashToSign,
    required String pin,
  }) async {
    // signTransactionHash signs a raw 32-byte digest (no EIP-191 prefix)
    return BmoniEmbeddedSdk.signTransactionHash(hashToSign, pin: pin);
  }

  /// Submit the signature to complete the proposal.
  static Future<Map<String, dynamic>> submitSignature({
    required String proposalId,
    required String signature,
  }) async {
    final userId = await ApiService.getStoredUserId();
    return ApiService.post(
      '/users/$userId/smart-wallets/proposals/$proposalId/sign',
      body: {'signature': signature},
    );
  }

  /// Get proposal status.
  static Future<Map<String, dynamic>> getProposalStatus(String proposalId) async {
    final userId = await ApiService.getStoredUserId();
    return ApiService.get('/users/$userId/smart-wallets/proposals/$proposalId');
  }

  /// Full send flow: create → approve → get payload → sign → submit.
  /// Returns the final proposal status.
  static Future<Map<String, dynamic>> sendMoney({
    required String recipientUserId,
    required String amount,
    required String currency,
    required String pin,
    String? description,
  }) async {
    // 1. Create proposal
    final proposal = await createProposal(
      recipientUserId: recipientUserId,
      amount: amount,
      currency: currency,
      description: description,
    );

    final proposalId = proposal['data']?['proposal']?['id'] ?? proposal['id'];
    if (proposalId == null) {
      throw Exception('No proposal ID returned');
    }

    // 2. Approve
    await approveProposal(proposalId);

    // 3. Wait for approval threshold, then get sign payload
    // Poll until status is PENDING_SIGNATURES
    Map<String, dynamic>? signPayload;
    for (var i = 0; i < 10; i++) {
      await Future.delayed(const Duration(seconds: 1));
      final status = await getProposalStatus(proposalId);
      final proposalStatus = status['data']?['proposal']?['status'] ?? status['status'];
      if (proposalStatus == 'PENDING_SIGNATURES') {
        signPayload = await getSignPayload(proposalId);
        break;
      }
      if (proposalStatus == 'COMPLETED') {
        return status;
      }
    }

    if (signPayload == null) {
      throw Exception('Proposal did not reach PENDING_SIGNATURES');
    }

    final hashToSign = signPayload['data']?['hashToSign'] ?? signPayload['hashToSign'];
    if (hashToSign == null) {
      throw Exception('No hashToSign in sign payload');
    }

    // 4. Sign on device
    final signature = await signProposalOnDevice(
      hashToSign: hashToSign,
      pin: pin,
    );

    // 5. Submit signature
    await submitSignature(proposalId: proposalId, signature: signature);

    // 6. Poll for completion
    for (var i = 0; i < 10; i++) {
      await Future.delayed(const Duration(seconds: 1));
      final status = await getProposalStatus(proposalId);
      final proposalStatus = status['data']?['proposal']?['status'] ?? status['status'];
      if (proposalStatus == 'COMPLETED' || proposalStatus == 'FAILED') {
        return status;
      }
    }

    return {'status': 'PENDING_SIGNATURES', 'proposalId': proposalId};
  }
}
