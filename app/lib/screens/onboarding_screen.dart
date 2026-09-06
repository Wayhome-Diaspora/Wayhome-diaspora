import 'package:flutter/material.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../services/wallet_service.dart';

/// Onboarding flow: creates BMONI user, provisions wallet, sets PIN.
/// Accepts ?role=sender or ?role=recipient from the splash screen.
class OnboardingScreen extends StatefulWidget {
  final String role;
  const OnboardingScreen({super.key, required this.role});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  bool _loading = false;
  String? _error;
  String? _walletAddress;

  // Form fields
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  final _pinConfirmController = TextEditingController();

  String get _roleLabel => widget.role == 'sender' ? 'Sender' : 'Recipient';

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _pinController.dispose();
    _pinConfirmController.dispose();
    super.dispose();
  }

  Future<void> _createUser() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ApiService.post('/users', {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'role': widget.role, // Our local role tag
      });

      final bmoniUserId = result['bmoniUserId'] ?? result['id'];
      if (bmoniUserId != null) {
        await ApiService.saveUserId(bmoniUserId);
      }

      setState(() {
        _step = 1;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to create account: $e';
      });
    }
  }

  Future<void> _provisionWallet() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final address = await WalletService.initWallet();
      setState(() {
        _walletAddress = address;
        _step = 2;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Wallet setup failed: $e';
      });
    }
  }

  Future<void> _setPin() async {
    if (_pinController.text != _pinConfirmController.text) {
      setState(() => _error = 'PINs do not match');
      return;
    }

    if (_pinController.text.length != BmoniEmbeddedSdk.pinLength) {
      setState(() => _error = 'PIN must be ${BmoniEmbeddedSdk.pinLength} digits');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await WalletService.setPin(_pinController.text);
      // Navigate to KYC (role-specific flow)
      if (mounted) context.go('/kyc?role=${widget.role}');
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'PIN setup failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Set up as $_roleLabel'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // Progress indicator
              _buildProgress(),
              const SizedBox(height: 32),
              // Content
              Expanded(child: _buildStepContent()),
              // Error display
              if (_error != null) _buildError(),
              // Action button
              _buildActionButton(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return Row(
      children: List.generate(3, (i) {
        final isActive = i <= _step;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildAccountForm();
      case 1:
        return _buildWalletProvisioning();
      case 2:
        return _buildPinSetup();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAccountForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create your account',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us a bit about yourself',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white60,
                ),
          ),
          const SizedBox(height: 32),
          _buildTextField(_firstNameController, 'First name'),
          const SizedBox(height: 16),
          _buildTextField(_lastNameController, 'Last name'),
          const SizedBox(height: 16),
          _buildTextField(_phoneController, 'Phone number (+234...)',
              keyboardType: TextInputType.phone),
          const SizedBox(height: 16),
          _buildTextField(_emailController, 'Email',
              keyboardType: TextInputType.emailAddress),
        ],
      ),
    );
  }

  Widget _buildWalletProvisioning() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_loading) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Creating your secure wallet...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'A cryptographic keypair is being generated\nin your device\'s secure hardware.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white60,
                  ),
            ),
          ] else ...[
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Colors.white,
            ),
            const SizedBox(height: 24),
            Text(
              'Your wallet is ready',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (_walletAddress != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_walletAddress!.substring(0, 10)}...${_walletAddress!.substring(_walletAddress!.length - 8)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPinSetup() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set your PIN',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'This PIN protects your signing key.\nYou\'ll need it every time you send money.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white60,
                ),
          ),
          const SizedBox(height: 32),
          _buildTextField(
            _pinController,
            'PIN (${BmoniEmbeddedSdk.pinLength} digits)',
            keyboardType: TextInputType.number,
            obscureText: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _pinConfirmController,
            'Confirm PIN',
            keyboardType: TextInputType.number,
            obscureText: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _error!,
        style: const TextStyle(color: Colors.red),
      ),
    );
  }

  Widget _buildActionButton() {
    final labels = ['Continue', 'Create wallet', 'Set PIN & finish'];
    final isLoading = _loading;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading
            ? null
            : () {
                switch (_step) {
                  case 0:
                    _createUser();
                    break;
                  case 1:
                    _provisionWallet();
                    break;
                  case 2:
                    _setPin();
                    break;
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                labels[_step],
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }
}
