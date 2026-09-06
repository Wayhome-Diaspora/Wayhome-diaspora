import 'package:flutter/material.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import 'package:go_router/go_router.dart';

import '../services/transfer_service.dart';

/// Send money screen — full send flow:
/// recipient selection → amount entry → review → PIN → send.
class SendMoneyScreen extends StatefulWidget {
  const SendMoneyScreen({super.key});

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  int _step = 0;
  bool _loading = false;
  String? _error;
  String? _success;

  // Form
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pinController = TextEditingController();

  // Mock recipient data (in real app, fetch from linked recipients)
  String _recipientName = '';
  String _recipientId = '';

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _selectRecipient() async {
    // In a real app, show a search/select UI for linked recipients
    // For now, accept a BMONI user ID
    final id = _recipientController.text.trim();
    if (id.isEmpty) {
      setState(() => _error = 'Enter a recipient user ID');
      return;
    }
    setState(() {
      _recipientId = id;
      _recipientName = 'Recipient'; // Would be fetched from API
      _step = 1;
      _error = null;
    });
  }

  Future<void> _reviewTransfer() async {
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

  Future<void> _sendMoney() async {
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
      final result = await TransferService.sendMoney(
        recipientUserId: _recipientId,
        amount: _amountController.text.trim(),
        currency: 'CNGN', // Send as NGN to recipient
        pin: pin,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
      );

      final status = result['data']?['proposal']?['status'] ?? result['status'];

      if (mounted) {
        setState(() { _loading = false; });
        BMoniToastOverlay.showSuccess(
          context: context,
          message: 'Money sent successfully!',
          title: 'Success',
        );
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) context.go('/home');
      }
    } catch (e) {
      setState(() { _loading = false; });
      if (mounted) {
        BMoniToastOverlay.showError(
          context: context,
          message: 'Send failed: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Money'),
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
        return _buildRecipientSelection();
      case 1:
        return _buildAmountEntry();
      case 2:
        return _buildReviewAndPin();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildRecipientSelection() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Who are you sending to?',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Enter the recipient\'s BMONI user ID or phone number',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 32),
          _buildTextField(_recipientController, 'Recipient user ID'),
          const SizedBox(height: 16),
          // Quick select buttons
          Wrap(
            spacing: 8,
            children: [
              _QuickSelectChip(
                label: 'Samson Jabo',
                onTap: () {
                  _recipientController.text = 'recipient-user-id';
                  _selectRecipient();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountEntry() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How much?', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Sending to $_recipientName',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 32),
          _buildTextField(
            _amountController,
            'Amount (NGN)',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          _buildTextField(_descriptionController, 'Description (optional)'),
          const SizedBox(height: 24),
          // Exchange rate display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Exchange rate',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white60)),
                Text('1 USD ≈ 1,550 NGN (indicative)',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewAndPin() {
    final amount = _amountController.text.trim();
    final desc = _descriptionController.text.trim();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review & confirm', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          // Summary card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _SummaryRow('To', _recipientName),
                const SizedBox(height: 12),
                _SummaryRow('Amount', '₦$amount'),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SummaryRow('Description', desc),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text('Enter your PIN to confirm',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          _buildTextField(
            _pinController,
            '6-digit PIN',
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
    final labels = ['Continue', 'Review', 'Send money'];
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
                    _selectRecipient();
                    break;
                  case 1:
                    _reviewTransfer();
                    break;
                  case 2:
                    _sendMoney();
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
        Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _QuickSelectChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickSelectChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(label),
        backgroundColor: Colors.white.withAlpha(15),
        side: BorderSide(color: Colors.white.withAlpha(30)),
      ),
    );
  }
}
