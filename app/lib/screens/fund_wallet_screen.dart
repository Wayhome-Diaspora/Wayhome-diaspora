import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bkey_uikit/bkey_uikit.dart';

import '../services/api_service.dart';

/// Fund wallet screen — role-aware.
/// Sender: shows USD virtual bank account details for ACH/wire deposit.
/// Recipient: shows NGN deposit account details.
class FundWalletScreen extends StatefulWidget {
  const FundWalletScreen({super.key});

  @override
  State<FundWalletScreen> createState() => _FundWalletScreenState();
}

class _FundWalletScreenState extends State<FundWalletScreen> {
  bool _loading = true;
  String? _error;
  String? _role;
  Map<String, dynamic>? _accountData;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadAccountInfo();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAccountInfo() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = await ApiService.getStoredUserId();
      if (userId == null) {
        setState(() {
          _loading = false;
          _error = 'No user session found';
        });
        return;
      }

      // Get local user info to determine role
      final localUser = await ApiService.get('/users/local/$userId');
      _role = localUser['role'] ?? 'sender';

      if (_role == 'sender') {
        await _loadUsdVba(userId);
      } else {
        await _loadNgnDeposit(userId);
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load account info: $e';
      });
    }
  }

  Future<void> _loadUsdVba(String userId) async {
    try {
      final vba = await ApiService.get('/users/$userId/vba/usd');
      final status = vba['status'] ?? 'none';

      setState(() {
        _accountData = vba;
        _loading = false;
      });

      // Poll if still provisioning
      if (status == 'provisioning' || status == 'pending') {
        _startPolling(userId);
      }
    } catch (e) {
      // VBA might not exist yet — show provision CTA
      setState(() {
        _accountData = {'status': 'none'};
        _loading = false;
      });
    }
  }

  Future<void> _loadNgnDeposit(String userId) async {
    try {
      final accounts = await ApiService.get('/users/$userId/bank-accounts/deposit-accounts/NGN');
      setState(() {
        _accountData = accounts;
        _loading = false;
      });
    } catch (e) {
      // NGN account might not be created yet
      setState(() {
        _accountData = {'accounts': []};
        _loading = false;
      });
    }
  }

  void _startPolling(String userId) {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final vba = await ApiService.get('/users/$userId/vba/usd');
        final status = vba['status'] ?? 'none';
        setState(() => _accountData = vba);

        if (status == 'active' || status == 'rejected' || status == 'failed') {
          _pollTimer?.cancel();
        }
      } catch (_) {
        // Keep polling on transient errors
      }
    });
  }

  Future<void> _provisionUsdAccount() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = await ApiService.getStoredUserId();
      if (userId == null) throw Exception('No user session');

      // Get smart wallet ID from wallet list
      final walletsData = await ApiService.get('/users/$userId/smart-wallets/account/wallets');
      final wallets = walletsData['wallets'] as List? ?? [];
      if (wallets.isEmpty) throw Exception('No wallet found');

      final smartWalletId = wallets.first['id'] ?? wallets.first['walletId'];

      // Start USA onboarding
      await ApiService.post('/users/$userId/onboarding/start-usa', {
        'smartWalletId': smartWalletId,
      });

      // Start polling for the VBA
      setState(() {
        _accountData = {'status': 'provisioning'};
        _loading = false;
      });
      _startPolling(userId);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to provision account: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_role == 'sender' ? 'Fund Wallet' : 'Deposit Account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _role == 'sender'
                  ? _buildUsdView()
                  : _buildNgnView(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadAccountInfo,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  // --- USD VBA View (Sender) ---

  Widget _buildUsdView() {
    final status = _accountData?['status'] ?? 'none';
    final account = _accountData?['account'];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Deposit USD',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Send ACH or wire to your virtual bank account.\nFunds arrive as USDB in your wallet.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white60,
                ),
          ),
          const SizedBox(height: 32),
          if (status == 'active' && account != null)
            _buildVbaDetails(account)
          else if (status == 'provisioning' || status == 'pending')
            _buildProvisioningStatus(status)
          else if (status == 'rejected')
            _buildRejectedStatus()
          else if (status == 'failed')
            _buildRetryProvision()
          else
            _buildProvisionCta(),
        ],
      ),
    );
  }

  Widget _buildVbaDetails(Map<String, dynamic> account) {
    return Column(
      children: [
        _DetailRow(label: 'Bank name', value: account['bankName'] ?? '—'),
        const SizedBox(height: 12),
        _DetailRow(label: 'Account name', value: account['accountName'] ?? '—'),
        const SizedBox(height: 12),
        _CopyableRow(label: 'Account number', value: account['accountNumber'] ?? '—'),
        const SizedBox(height: 12),
        _CopyableRow(label: 'Routing number', value: account['routingNumber'] ?? '—'),
        if (account['swiftCode'] != null) ...[
          const SizedBox(height: 12),
          _CopyableRow(label: 'SWIFT code', value: account['swiftCode']),
        ],
        if (account['depositMessage'] != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Include this reference: ${account['depositMessage']}',
                    style: const TextStyle(color: Colors.amber),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'ACH typically arrives within 1-2 business days.\nWire transfers arrive same day.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white54,
              ),
        ),
      ],
    );
  }

  Widget _buildProvisioningStatus(String status) {
    return Center(
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            status == 'provisioning'
                ? 'Setting up your bank account...'
                : 'Awaiting bank verification...',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'This usually takes a few seconds in sandbox.\nWe\'ll update automatically when ready.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white60,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildProvisionCta() {
    return Center(
      child: Column(
        children: [
          Icon(
            Icons.account_balance_outlined,
            size: 64,
            color: Colors.white38,
          ),
          const SizedBox(height: 24),
          Text(
            'No bank account yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Get your USD virtual bank account\nto receive deposits.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white60,
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _provisionUsdAccount,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text('Get bank account'),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedStatus() {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.block, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Account provisioned but rejected',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _accountData?['reason'] ?? 'Contact support for details.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _buildRetryProvision() {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.refresh, size: 48, color: Colors.amber),
          const SizedBox(height: 16),
          Text(
            'Provisioning failed',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _provisionUsdAccount,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // --- NGN Deposit View (Recipient) ---

  Widget _buildNgnView() {
    final accounts = _accountData?['accounts'] as List? ?? [];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NGN Deposit Account',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Transfer NGN to this account.\nFunds arrive as CNGN in your wallet.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white60,
                ),
          ),
          const SizedBox(height: 32),
          if (accounts.isNotEmpty)
            ...accounts.map((a) => _buildNgnAccountCard(a))
          else
            _buildNgnEmpty(),
        ],
      ),
    );
  }

  Widget _buildNgnAccountCard(Map<String, dynamic> account) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            account['bankName'] ?? 'Nigerian Bank',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _CopyableRow(label: 'Account number', value: account['accountNumber'] ?? '—'),
          const SizedBox(height: 8),
          _CopyableRow(label: 'Bank code', value: account['bankCode'] ?? '—'),
        ],
      ),
    );
  }

  Widget _buildNgnEmpty() {
    return Center(
      child: Column(
        children: [
          Icon(
            Icons.account_balance_outlined,
            size: 64,
            color: Colors.white38,
          ),
          const SizedBox(height: 16),
          Text(
            'Your NGN account is being set up.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white60,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'It will appear here once onboarding is complete.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white54,
                ),
          ),
        ],
      ),
    );
  }
}

// --- Reusable widgets ---

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white60,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _CopyableRow extends StatelessWidget {
  final String label;
  final String value;

  const _CopyableRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white60,
              ),
        ),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Copied $label'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.copy, size: 14, color: Colors.white54),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
