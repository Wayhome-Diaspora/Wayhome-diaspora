import 'package:bmoni_embedded_sdk/bmoni_embedded_sdk.dart';

/// Wraps bmoni_embedded_sdk for wallet provisioning and PIN management.
/// All operations happen on-device — the private key never leaves secure hardware.
class WalletService {
  /// Check if a wallet already exists on this device.
  static Future<bool> hasWallet() async {
    return BmoniEmbeddedSdk.hasWallet();
  }

  /// Get the cached wallet address (returns null if no wallet).
  static Future<String?> getWalletAddress() async {
    return BmoniEmbeddedSdk.walletAddress();
  }

  /// Provision a new on-device wallet.
  /// Returns the EIP-55 checksummed address.
  /// Throws BmoniSignerException if a wallet already exists.
  static Future<String> initWallet() async {
    return BmoniEmbeddedSdk.initWallet();
  }

  /// Check if a signing PIN is set.
  static Future<bool> hasPin() async {
    return BmoniEmbeddedSdk.hasPin();
  }

  /// Set the signing PIN. Must be exactly BmoniEmbeddedSdk.pinLength characters.
  /// Throws BmoniSignerException if PIN already set or length is wrong.
  static Future<void> setPin(String pin) async {
    await BmoniEmbeddedSdk.setPin(pin);
  }

  /// Verify a PIN without throwing. Returns true if it matches.
  static Future<bool> verifyPin(String pin) async {
    return BmoniEmbeddedSdk.matchPin(pin);
  }

  /// Get or create wallet address (startup pattern from docs).
  static Future<String> getOrCreateWallet() async {
    if (await BmoniEmbeddedSdk.hasWallet()) {
      return (await BmoniEmbeddedSdk.walletAddress())!;
    }
    return BmoniEmbeddedSdk.initWallet();
  }

  /// Full onboarding: ensure wallet exists and PIN is set.
  /// Returns the wallet address. Throws on errors.
  static Future<String> onboard({String? pin}) async {
    final address = await getOrCreateWallet();

    if (!await BmoniEmbeddedSdk.hasPin()) {
      final setPinTo = pin ?? '123456'; // Default for dev; real UI collects this
      await BmoniEmbeddedSdk.setPin(setPinTo);
    }

    return address;
  }
}
