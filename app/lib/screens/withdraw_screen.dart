import 'package:flutter/material.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import 'package:go_router/go_router.dart';

import '../services/withdrawal_service.dart';

/// Withdraw to bank screen — full withdrawal flow:
/// select bank → enter account → verify (show name) → confirm → PIN → offramp.
class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  int _step = 0;
  bool _loading = false;
  String? _error;
  String? _success;

  // Form
  final _accountNumberController = TextEditingController();
  final _amountController = TextEditingController();
  final _pinController = TextEditingController();

  // Bank data
  List<dynamic> _banks = [];
  String? _selectedBankCode;
  String? _selectedBankName;

  // Verification result
  String? _verifiedAccountName;

  @override
  void initState() {
    super.initState();
    _loadBanks();
  }

  Future<void> _loadBanks() async {
    try {
      final banks = await WithdrawalService.getNigerianBanks();
      if (mounted) setState(() => _banks = banks);
    } catch (e) {
      // Banks will be empty; user can still proceed with manual entry
    }
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _amountController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _verifyAccount() async {
    if (_accountNumberController.text.trim().length != 10) {
      setState(() => _error = 'Account number must be 10 digits');
      return;
    }
    if (_selectedBankCode == null) {
      setState(() => _error = 'Select a bank');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await WithdrawalService.verifyAccount(
        accountNumber: _accountNumberController.text.trim(),
        bankCode: _selectedBankCode!,
      );

      final name = result['accountHolderName'] ?? result['name'] ?? 'Unknown';
      setState(() {
        _verifiedAccountName = name;
        _step = 1;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Verification failed: $e';
      });
    }
  }

  Future<void> _confirmWithdrawal() async {
    final amount = _amountController.text.trim();
    if (amount.isEmpty || double.tryParse(amount) == null) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }

    setState(() {
      _step = 2;
      _error = null;
    });
  }

  Future<void> _executeWithdrawal() async {
    final pin = _pinController.text.trim();
    if (pin.length != 6) {
      setState(() => _error = 'PIN must be 6 digits');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // For now, use a placeholder smart wallet ID
      // In production, fetch the user's active wallet
      final result = await WithdrawalService.withdraw(
        smartWalletId: 'placeholder-wallet-id',
        accountNumber: _accountNumberController.text.trim(),
        bankCode: _selectedBankCode!,
        bankName: _selectedBankName ?? '',
        fromAmount: _amountController.text.trim(),
        pin: pin,
      );

      final status = result['status'] ?? 'submitted';

      if (mounted) {
        setState(() {
          _loading = false;
          _success = 'Withdrawal submitted! Status: $status';
        });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) context.go('/home');
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Withdrawal failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdraw to Bank'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              _buildProgress(),
              const SizedBox(height: 24),
              Expanded(child: _buildStepContent()),
              if (_error != null) _buildError(),
              if (_success != null) _buildSuccess(),
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
        return _buildBankSelection();
      case 1:
        return _buildAmountEntry();
      case 2:
        return _buildReviewAndPin();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBankSelection() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bank account details',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Enter the Nigerian bank account to withdraw to',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 24),
          // Bank selector
          DropdownButtonFormField<String>(
            value: _selectedBankCode,
            decoration: const InputDecoration(
              labelText: 'Select bank',
              labelStyle: TextStyle(color: Colors.white60),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
            ),
            dropdownColor: const Color(0xFF1A1A2E),
            items: _banks.map<DropdownMenuItem<String>>((bank) {
              return DropdownMenuItem(
                value: bank['code'] ?? bank['bankCode'],
                child: Text(bank['name'] ?? bank['bankName'] ?? 'Unknown'),
              );
            }).toList(),
            onChanged: (value) {
              final bank = _banks.firstWhere(
                (b) => (b['code'] ?? b['bankCode']) == value,
                orElse: () => {},
              );
              setState(() {
                _selectedBankCode = value;
                _selectedBankName = bank['name'] ?? bank['bankName'];
              });
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(_accountNumberController, 'Account number (10 digits)',
              keyboardType: TextInputType.number),
        ],
      ),
    );
  }

  Widget _buildAmountEntry() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Verify account', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          // Trust pattern: show resolved account name
          if (_verifiedAccountName != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withAlpha(50)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text('Account verified',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              )),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Account holder: $_verifiedAccountName',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          )),
                  Text('Account: ${_accountNumberController.text}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white60,
                          )),
                  Text('Bank: $_selectedBankName',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white60,
                          )),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text('How much to withdraw?',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          _buildTextField(_amountController, 'Amount (NGN)',
              keyboardType: TextInputType.number),
        ],
      ),
    );
  }

  Widget _buildReviewAndPin() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Confirm withdrawal', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _SummaryRow('Bank', _selectedBankName ?? ''),
                const SizedBox(height: 12),
                _SummaryRow('Account', _accountNumberController.text),
                const SizedBox(height: 12),
                _SummaryRow('Account holder', _verifiedAccountName ?? ''),
                const SizedBox(height: 12),
                _SummaryRow('Amount', '₦${_amountController.text}'),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text('Enter your PIN to confirm',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          _buildTextField(_pinController, '6-digit PIN',
              keyboardType: TextInputType.number, obscureText: true),
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
      child: Text(_error!, style: const TextStyle(color: Colors.red)),
    );
  }

  Widget _buildSuccess() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(_success!, style: const TextStyle(color: Colors.green)),
    );
  }

  Widget _buildActionButton() {
    final labels = ['Verify account', 'Continue', 'Withdraw'];
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
                    _verifyAccount();
                    break;
                  case 1:
                    _confirmWithdrawal();
                    break;
                  case 2:
                    _executeWithdrawal();
                    break;
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(labels[_step],
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white60)),
        Expanded(
          child: Text(value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
