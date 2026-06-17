import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final auth = ref.read(authProvider);
    final error = await auth.sendPasswordResetEmail(_emailCtrl.text);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: EHadirTheme.rejected,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() => _emailSent = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lupa Kata Laluan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 40),
          child: _emailSent ? _buildSuccessState() : _buildFormState(),
        ),
      ),
    );
  }

  Widget _buildFormState() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: EHadirTheme.primaryGradient,
              borderRadius: BorderRadius.circular(EHadirTheme.radiusLg),
              boxShadow: EHadirTheme.glowShadow,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(EHadirTheme.radiusSm),
                  ),
                  child: const Icon(Icons.lock_reset_rounded,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Set Semula Kata Laluan',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Pautan reset akan dihantar ke e-mel anda',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          const Text(
            'Masukkan alamat e-mel yang anda gunakan semasa mendaftar. '
            'Kami akan menghantar pautan untuk menetapkan semula kata laluan anda.',
            style: TextStyle(
                color: EHadirTheme.textSecondary, fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 28),

          // Email field
          Text(
            'E-mel',
            style: const TextStyle(
                color: EHadirTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            style: const TextStyle(color: EHadirTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Contoh: nama@ikm.edu.my',
              prefixIcon: Icon(Icons.email_outlined,
                  color: EHadirTheme.textSecondary, size: 20),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Sila masukkan e-mel';
              }
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim())) {
                return 'Format e-mel tidak sah';
              }
              return null;
            },
          ),
          const SizedBox(height: 28),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: EHadirTheme.accent,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _isLoading ? 'Menghantar...' : 'Hantar Pautan Reset',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Kembali ke Log Masuk',
                style: TextStyle(color: EHadirTheme.accent, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Column(
      children: [
        const SizedBox(height: 40),
        // Success icon
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: EHadirTheme.approved.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_rounded,
              color: EHadirTheme.approved, size: 56),
        ),
        const SizedBox(height: 28),

        const Text(
          'E-mel Telah Dihantar!',
          style: TextStyle(
              color: EHadirTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        Text(
          'Pautan untuk menetapkan semula kata laluan telah dihantar ke:\n\n${_emailCtrl.text.trim()}',
          style: const TextStyle(
              color: EHadirTheme.textSecondary, fontSize: 14, height: 1.6),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        const Text(
          'Sila semak peti masuk anda (termasuk folder Spam).\n'
          'Pautan ini akan tamat tempoh dalam masa 1 jam.',
          style: TextStyle(
              color: EHadirTheme.textSecondary, fontSize: 13, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),

        // Back to login button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: EHadirTheme.accent,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text(
              'Kembali ke Log Masuk',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Resend option
        TextButton(
          onPressed: () => setState(() {
            _emailSent = false;
            _emailCtrl.clear();
          }),
          child: const Text(
            'Tidak terima e-mel? Cuba semula',
            style: TextStyle(color: EHadirTheme.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
