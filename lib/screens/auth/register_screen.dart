import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../../models/department.dart';
import '../../models/user.dart';
import '../../theme.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  UserRole _selectedRole = UserRole.pensyarah;
  String _selectedProgram = kPrograms.first;
  String _selectedDepartment = Department.all.first;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final auth = ref.read(authProvider);
    String programOrDept;
    if (_selectedRole == UserRole.admin ||
        _selectedRole == UserRole.timbalanPengarahAkademik) {
      programOrDept = 'Global';
    } else if (_selectedRole == UserRole.ketuaJabatan) {
      programOrDept = _selectedDepartment;
    } else {
      programOrDept = _selectedProgram;
    }
    final error = await auth.register(
      name: _nameCtrl.text,
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
      role: _selectedRole,
      program: programOrDept,
    );

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
      // Account created but pending admin approval — show dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: EHadirTheme.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(EHadirTheme.radiusLg),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: EHadirTheme.pending.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(EHadirTheme.radiusSm),
                  ),
                  child: const Icon(Icons.hourglass_top_rounded,
                      color: EHadirTheme.pending, size: 22),
                ),
                const SizedBox(width: 12),
                const Text('Permohonan Dihantar',
                    style: TextStyle(
                        color: EHadirTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            content: const Text(
              'Akaun anda telah didaftarkan dan sedang menunggu kelulusan admin.\n\n'
              'Anda akan dapat log masuk setelah admin meluluskan permohonan anda.',
              style: TextStyle(
                  color: EHadirTheme.textSecondary,
                  fontSize: 14,
                  height: 1.5),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: EHadirTheme.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
                  ),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop(); // close dialog
                  Navigator.of(context).pop(); // return to login screen
                },
                child: const Text('Faham, Kembali ke Log Masuk',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Akaun'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
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
                        child: const Icon(Icons.person_add_rounded,
                            color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Daftar Akaun Baharu',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700)),
                            SizedBox(height: 2),
                            Text('Isi maklumat di bawah untuk mendaftar',
                                style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Nama Penuh ──────────────────────────────
                _fieldLabel('Nama Penuh'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: EHadirTheme.textPrimary),
                  decoration: _inputDeco(
                      hint: 'Contoh: Ahmad bin Razak',
                      icon: Icons.person_outline_rounded),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Sila masukkan nama penuh';
                    }
                    if (v.trim().length < 3) return 'Nama terlalu pendek';
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // ── E-mel ───────────────────────────────────
                _fieldLabel('E-mel'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: EHadirTheme.textPrimary),
                  decoration: _inputDeco(
                      hint: 'Contoh: nama@graduate.utm.my',
                      icon: Icons.email_outlined),
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
                const SizedBox(height: 18),

                // ── Kata Laluan ─────────────────────────────
                _fieldLabel('Kata Laluan'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: EHadirTheme.textPrimary),
                  decoration: _inputDeco(
                    hint: 'Sekurang-kurangnya 6 aksara',
                    icon: Icons.lock_outline_rounded,
                  ).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: EHadirTheme.textSecondary,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Sila masukkan kata laluan';
                    if (v.length < 6) return 'Minimum 6 aksara';
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // ── Sahkan Kata Laluan ──────────────────────
                _fieldLabel('Sahkan Kata Laluan'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  style: const TextStyle(color: EHadirTheme.textPrimary),
                  decoration: _inputDeco(
                    hint: 'Ulang kata laluan',
                    icon: Icons.lock_outline_rounded,
                  ).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: EHadirTheme.textSecondary,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Sila sahkan kata laluan';
                    }
                    if (v != _passwordCtrl.text) {
                      return 'Kata laluan tidak sepadan';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // ── Peranan (Role) ──────────────────────────
                _fieldLabel('Peranan'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: EHadirTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<UserRole>(
                      value: _selectedRole,
                      isExpanded: true,
                      dropdownColor: EHadirTheme.card,
                      style: const TextStyle(
                          color: EHadirTheme.textPrimary, fontSize: 15),
                      icon: const Icon(Icons.expand_more_rounded,
                          color: EHadirTheme.textSecondary),
                      items: UserRole.values
                          .map((r) => DropdownMenuItem(
                                value: r,
                                child: Row(
                                  children: [
                                    Icon(_roleIcon(r),
                                        size: 18,
                                        color: _roleColor(r)),
                                    const SizedBox(width: 10),
                                    Text(r.displayName),
                                  ],
                                ),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedRole = v ?? _selectedRole),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // ── Program / Department ────────────────────
                if (_selectedRole == UserRole.ketuaJabatan) ...[
                  _fieldLabel('Jabatan'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: EHadirTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedDepartment,
                        isExpanded: true,
                        dropdownColor: EHadirTheme.card,
                        style: const TextStyle(
                            color: EHadirTheme.textPrimary, fontSize: 15),
                        icon: const Icon(Icons.expand_more_rounded,
                            color: EHadirTheme.textSecondary),
                        items: Department.all
                            .map((d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(d),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() =>
                            _selectedDepartment = v ?? _selectedDepartment),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ] else if (_selectedRole != UserRole.admin &&
                    _selectedRole != UserRole.timbalanPengarahAkademik) ...[
                  _fieldLabel('Program'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: EHadirTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedProgram,
                        isExpanded: true,
                        dropdownColor: EHadirTheme.card,
                        style: const TextStyle(
                            color: EHadirTheme.textPrimary, fontSize: 15),
                        icon: const Icon(Icons.expand_more_rounded,
                            color: EHadirTheme.textSecondary),
                        items: kPrograms
                            .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(p),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedProgram = v ?? _selectedProgram),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ] else ...[
                  const SizedBox(height: 14),
                ],

                // ── Submit ──────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EHadirTheme.accent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Daftar Sekarang',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Sudah ada akaun? Log Masuk',
                      style: TextStyle(color: EHadirTheme.accent, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: EHadirTheme.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _inputDeco({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: EHadirTheme.textSecondary, size: 20),
    );
  }

  IconData _roleIcon(UserRole role) {
    switch (role) {
      case UserRole.pensyarah:
        return Icons.school_rounded;
      case UserRole.admin:
        return Icons.admin_panel_settings_rounded;
      case UserRole.ketuaProgram:
        return Icons.manage_accounts_rounded;
      case UserRole.ketuaJabatan:
        return Icons.corporate_fare_rounded;
      case UserRole.timbalanPengarahAkademik:
        return Icons.stars_rounded;
    }
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.pensyarah:
        return EHadirTheme.accent;
      case UserRole.admin:
        return const Color(0xFF7C4DFF);
      case UserRole.ketuaProgram:
        return const Color(0xFF26A69A);
      case UserRole.ketuaJabatan:
        return const Color(0xFFFF7043);
      case UserRole.timbalanPengarahAkademik:
        return const Color(0xFFFFD54F);
    }
  }
}
