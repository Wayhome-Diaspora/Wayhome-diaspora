import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/kyc_service.dart';
import '../services/api_service.dart';

/// KYC screen — multi-step identity verification wizard.
/// Sender path: Global KYC (id-and-liveness) with full document uploads.
/// Recipient path: Nigeria KYC via BVN (simpler, no biometric).
class KycScreen extends StatefulWidget {
  final String role;
  const KycScreen({super.key, required this.role});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  int _step = 0;
  bool _loading = false;
  String? _error;
  String? _success;

  // Form controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _bvnController = TextEditingController();
  final _employmentStatusController = TextEditingController();
  final _sourceOfFundsController = TextEditingController();
  final _monthlyVolumeController = TextEditingController();

  bool get _isSender => widget.role == 'sender';

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _bvnController.dispose();
    _employmentStatusController.dispose();
    _sourceOfFundsController.dispose();
    _monthlyVolumeController.dispose();
    super.dispose();
  }

  // --- Sender flow steps ---
  // 0: Personal info
  // 1: Address
  // 2: Employment & compliance
  // 3: Activate Global KYC

  // --- Recipient flow steps ---
  // 0: BVN lookup
  // 1: Personal info (from BVN)
  // 2: Address
  // 3: Activate Nigeria KYC

  int get _totalSteps => 4;

  Future<void> _submitStep() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      switch (_step) {
        case 0:
          await _submitPersonalInfo();
          break;
        case 1:
          await _submitAddress();
          break;
        case 2:
          if (_isSender) {
            await _submitEmployment();
          }
          // Recipient skips employment
          break;
        case 3:
          await _activateKyc();
          return; // Navigate away after activation
      }

      if (mounted && _step < _totalSteps - 1) {
        setState(() {
          _step++;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Step failed: $e';
      });
    }
  }

  Future<void> _submitPersonalInfo() async {
    if (_isSender) {
      // Sender: manual entry
      await KycService.submitProfile(
        personalInfo: {
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'dateOfBirth': _dobController.text.trim(),
          'gender': 'male', // TODO: make selectable
        },
      );
    } else {
      // Recipient: BVN lookup first, then save profile
      final bvn = _bvnController.text.trim();
      if (bvn.length != 11) {
        throw Exception('BVN must be exactly 11 digits');
      }

      // BVN lookup (fetch only)
      final lookup = await KycService.bvnLookup(bvn);
      _firstNameController.text = lookup['firstName'] ?? '';
      _lastNameController.text = lookup['lastName'] ?? '';
      _dobController.text = lookup['dateOfBirth'] ?? '';

      // Save profile
      await KycService.submitProfile(
        personalInfo: {
          'firstName': lookup['firstName'],
          'lastName': lookup['lastName'],
          'dateOfBirth': lookup['dateOfBirth'],
          'phoneNumber': lookup['phoneNumber'],
        },
        identificationNumbers: {
          'bvn': bvn,
        },
      );
    }
  }

  Future<void> _submitAddress() async {
    await KycService.submitProfile(
      addressDetails: {
        'streetLine1': _streetController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'postalCode': _postalCodeController.text.trim(),
        'countryCode': _isSender ? 'USA' : 'NGA',
      },
    );
  }

  Future<void> _submitEmployment() async {
    await KycService.submitProfile(
      employment: {
        'employmentStatus': _employmentStatusController.text.trim(),
      },
      compliance: {
        'sourceOfFunds': _sourceOfFundsController.text.trim(),
        'estimatedMonthlyVolume': _monthlyVolumeController.text.trim(),
        'accountPurpose': 'personal',
      },
    );
  }

  Future<void> _activateKyc() async {
    if (_isSender) {
      // Global KYC — requires sumsubLevelName
      await KycService.activate(sumsubLevelName: 'id-and-liveness');
    } else {
      // Nigeria KYC — no sumsubLevelName
      await KycService.activate();
    }

    // Check status
    final status = await KycService.getOnboardingStatus();

    if (mounted) {
      setState(() {
        _loading = false;
        _success = 'KYC submitted! Status: ${status['status'] ?? 'pending'}';
      });

      // Navigate to home after a brief delay
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSender ? 'Verify Identity' : 'Verify Identity (Nigeria)'),
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
      children: List.generate(_totalSteps, (i) {
        final isActive = i <= _step;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i < _totalSteps - 1 ? 8 : 0),
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
        return _isSender ? _buildSenderPersonalInfo() : _buildRecipientBvn();
      case 1:
        return _isSender ? _buildSenderAddress() : _buildRecipientAddress();
      case 2:
        return _isSender ? _buildSenderEmployment() : _buildActivateStep();
      case 3:
        return _buildActivateStep();
      default:
        return const SizedBox.shrink();
    }
  }

  // --- Sender steps ---

  Widget _buildSenderPersonalInfo() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personal Information', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Tell us about yourself', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white60)),
          const SizedBox(height: 24),
          _buildTextField(_firstNameController, 'First name'),
          const SizedBox(height: 16),
          _buildTextField(_lastNameController, 'Last name'),
          const SizedBox(height: 16),
          _buildTextField(_dobController, 'Date of birth (YYYY-MM-DD)',
              keyboardType: TextInputType.datetime),
        ],
      ),
    );
  }

  Widget _buildSenderAddress() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Address', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Your US address', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white60)),
          const SizedBox(height: 24),
          _buildTextField(_streetController, 'Street address'),
          const SizedBox(height: 16),
          _buildTextField(_cityController, 'City'),
          const SizedBox(height: 16),
          _buildTextField(_stateController, 'State'),
          const SizedBox(height: 16),
          _buildTextField(_postalCodeController, 'Postal code',
              keyboardType: TextInputType.number),
        ],
      ),
    );
  }

  Widget _buildSenderEmployment() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Employment & Compliance', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Required for USD account', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white60)),
          const SizedBox(height: 24),
          _buildTextField(_employmentStatusController, 'Employment status'),
          const SizedBox(height: 16),
          _buildTextField(_sourceOfFundsController, 'Source of funds'),
          const SizedBox(height: 16),
          _buildTextField(_monthlyVolumeController, 'Estimated monthly volume (USD)',
              keyboardType: TextInputType.number),
        ],
      ),
    );
  }

  // --- Recipient steps ---

  Widget _buildRecipientBvn() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bank Verification Number', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Enter your 11-digit BVN. We\'ll verify your identity automatically.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 24),
          _buildTextField(_bvnController, 'BVN (11 digits)',
              keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your name and date of birth will be fetched from the BVN record.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientAddress() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nigerian Address', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Your address in Nigeria', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white60)),
          const SizedBox(height: 24),
          _buildTextField(_streetController, 'Street address'),
          const SizedBox(height: 16),
          _buildTextField(_cityController, 'City'),
          const SizedBox(height: 16),
          _buildTextField(_stateController, 'State'),
          const SizedBox(height: 16),
          _buildTextField(_postalCodeController, 'Postal code (6 digits)',
              keyboardType: TextInputType.number),
        ],
      ),
    );
  }

  Widget _buildActivateStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isSender ? Icons.verified_user_outlined : Icons.shield_outlined,
            size: 64,
            color: Colors.white,
          ),
          const SizedBox(height: 24),
          Text(
            'Ready to verify',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _isSender
                ? 'We\'ll run identity verification with liveness check. This takes a few moments.'
                : 'We\'ll verify your BVN against your profile. This is instant in the sandbox.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white60),
          ),
        ],
      ),
    );
  }

  // --- Shared widgets ---

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
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
    final labels = ['Continue', 'Continue', 'Continue', _isSender ? 'Start verification' : 'Verify & finish'];
    final isLoading = _loading;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : _submitStep,
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
            : Text(
                labels[_step],
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
      ),
    );
  }
}
