import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';
import '../../theme.dart';
import '../../utils/dialogs.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  List<AppUser> _users = [];
  bool _loading = true;

  // Search + role filter (UX upgrade for scrolling long user lists).
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  UserRole? _roleFilter; // null = show all roles

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    final auth = ref.read(authProvider);
    final users = await auth.fetchAllUsers();
    if (mounted) setState(() { _users = users; _loading = false; });
  }

  /// Returns users that match the active role filter AND the search query.
  List<AppUser> get _filteredUsers {
    final q = _searchQuery.trim().toLowerCase();
    return _users.where((u) {
      if (_roleFilter != null && u.role != _roleFilter) return false;
      if (q.isEmpty) return true;
      return u.name.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q);
    }).toList();
  }

  /// Per-role counts for the filter chip badges.
  Map<UserRole?, int> get _roleCounts {
    final counts = <UserRole?, int>{null: _users.length};
    for (final role in UserRole.values) {
      counts[role] = _users.where((u) => u.role == role).length;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final current = auth.currentUser!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Log Keluar',
          onPressed: () => showLogoutConfirmation(context, ref),
        ),
        title: const Text('Admin — Urus Pengguna'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Log Keluar',
            onPressed: () => showLogoutConfirmation(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4A148C), Color(0xFF7C4DFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(EHadirTheme.radiusLg),
              boxShadow: EHadirTheme.cardShadow,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(current.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('${_users.length} pengguna berdaftar',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  onPressed: _loadUsers,
                ),
              ],
            ),
          ),

          // Search bar + role filter chips
          if (!_loading && _users.isNotEmpty) _buildSearchAndFilter(),

          // User list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                    ? const Center(
                        child: Text('Tiada pengguna berdaftar.',
                            style: TextStyle(color: EHadirTheme.textSecondary)))
                    : _filteredUsers.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Tiada pengguna sepadan dengan carian / tapisan.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: EHadirTheme.textSecondary),
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadUsers,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 40),
                              itemCount: _filteredUsers.length,
                              itemBuilder: (ctx, i) =>
                                  _buildUserTile(_filteredUsers[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  // ─── Search + role filter UI ────────────────────────────

  Widget _buildSearchAndFilter() {
    final counts = _roleCounts;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Cari nama atau email...',
              prefixIcon: const Icon(Icons.search_rounded,
                  color: EHadirTheme.textSecondary, size: 20),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),

          // Role filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _roleChip(null, 'Semua', counts[null] ?? 0),
                for (final role in UserRole.values)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _roleChip(role, role.displayName, counts[role] ?? 0),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleChip(UserRole? role, String label, int count) {
    final selected = _roleFilter == role;
    final color = role == null ? EHadirTheme.primary : _roleColor(role);
    return FilterChip(
      label: Text('$label  ·  $count'),
      selected: selected,
      onSelected: (_) => setState(() => _roleFilter = role),
      selectedColor: color.withValues(alpha: 0.15),
      checkmarkColor: color,
      side: BorderSide(color: selected ? color : EHadirTheme.divider),
      labelStyle: TextStyle(
        color: selected ? color : EHadirTheme.textPrimary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
    );
  }

  Widget _buildUserTile(AppUser user) {
    final roleColor = _roleColor(user.role);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: EHadirTheme.card,
        borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
        border: Border.all(color: EHadirTheme.divider),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.fromLTRB(16, 12, 16, 4),
            leading: CircleAvatar(
              backgroundColor: roleColor.withValues(alpha: 0.2),
              child: Text(
                user.name.split(' ').map((w) => w[0]).take(2).join(),
                style: TextStyle(
                    color: roleColor, fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            title: Text(user.name,
                style: const TextStyle(
                    color: EHadirTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(user.email,
                    style: const TextStyle(
                        color: EHadirTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 4),
                Text('Kata Laluan: •••••••• (${user.passwordHash})',
                    style: TextStyle(
                        color: EHadirTheme.textSecondary.withValues(alpha: 0.7), fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _roleBadge(user.role),
                    if (user.program.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _programBadge(user.program),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: EHadirTheme.divider, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _resetUserPassword(user),
                  icon: const Icon(Icons.lock_reset_rounded, size: 18),
                  label: const Text('Reset Password'),
                  style: TextButton.styleFrom(foregroundColor: EHadirTheme.pending),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showUserDetail(user),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EHadirTheme.surfaceLight,
                    foregroundColor: EHadirTheme.textPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resetUserPassword(AppUser user) async {
    final auth = ref.read(authProvider);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final newPw = await auth.simulatePasswordReset(user);
    if (!mounted) return;
    if (newPw != null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
              'E-mel kata laluan baharu telah dihantar ke ${user.email}.\nKata laluan sementara: $newPw'),
          backgroundColor: EHadirTheme.accent,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  void _showUserDetail(AppUser user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: EHadirTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(EHadirTheme.radiusXl)),
      ),
      builder: (ctx) => _UserDetailSheet(
        user: user,
        onSave: (updated) async {
          final auth = ref.read(authProvider);
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          final err = await auth.updateUser(updated);
          if (!mounted) return;
          if (err != null) {
            scaffoldMessenger.showSnackBar(
                SnackBar(content: Text(err), backgroundColor: EHadirTheme.rejected));
          } else {
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('Profil berjaya dikemaskini'),
                backgroundColor: EHadirTheme.approved,
              ),
            );
            _loadUsers();
          }
        },
        onResetPassword: (u) async {
          final auth = ref.read(authProvider);
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          final newPw = await auth.simulatePasswordReset(u);
          if (!mounted) return;
          if (newPw != null) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                    'E-mel kata laluan baharu telah dihantar ke ${u.email}.\nKata laluan sementara: $newPw'),
                backgroundColor: EHadirTheme.accent,
                duration: const Duration(seconds: 6),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _roleBadge(UserRole role) {
    final color = _roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(role.displayName,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _programBadge(String program) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: EHadirTheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(program,
          style: const TextStyle(
              color: EHadirTheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
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

// ─── User Detail Sheet ────────────────────────────────────────

class _UserDetailSheet extends StatefulWidget {
  final AppUser user;
  final Future<void> Function(AppUser updated) onSave;
  final Future<void> Function(AppUser u) onResetPassword;

  const _UserDetailSheet(
      {required this.user, required this.onSave, required this.onResetPassword});

  @override
  State<_UserDetailSheet> createState() => _UserDetailSheetState();
}

class _UserDetailSheetState extends State<_UserDetailSheet> {
  late TextEditingController _nameCtrl;
  late UserRole _role;
  late String _program;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.name);
    _role = widget.user.role;
    _program = getSafeProgram(widget.user.program);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, sc) => ListView(
        controller: sc,
        padding: const EdgeInsets.all(24),
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: EHadirTheme.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),

          Text('Maklumat Pengguna',
              style: const TextStyle(
                  color: EHadirTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),

          // Read-only fields
          _infoRow('E-mel', widget.user.email),
          _infoRow('Kata Laluan', '••••••••  (${widget.user.passwordHash})'),
          const Divider(color: EHadirTheme.divider, height: 28),

          // Editable: Nama
          const Text('Nama', style: TextStyle(color: EHadirTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: EHadirTheme.textPrimary),
            decoration: const InputDecoration(hintText: 'Nama penuh'),
          ),
          const SizedBox(height: 16),

          // Editable: Peranan
          const Text('Peranan', style: TextStyle(color: EHadirTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: EHadirTheme.surfaceLight,
              borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<UserRole>(
                value: _role,
                isExpanded: true,
                dropdownColor: EHadirTheme.card,
                style: const TextStyle(color: EHadirTheme.textPrimary, fontSize: 15),
                items: UserRole.values
                    .map((r) => DropdownMenuItem(
                        value: r, child: Text(r.displayName)))
                    .toList(),
                onChanged: (v) => setState(() => _role = v ?? _role),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Editable: Program
          if (_role != UserRole.admin && _role != UserRole.timbalanPengarahAkademik) ...[
            const Text('Program', style: TextStyle(color: EHadirTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: EHadirTheme.surfaceLight,
                borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _program,
                  isExpanded: true,
                  dropdownColor: EHadirTheme.card,
                  style: const TextStyle(color: EHadirTheme.textPrimary, fontSize: 15),
                  items: kPrograms
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => setState(() => _program = v ?? _program),
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],

          // Save
          ElevatedButton.icon(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    await widget.onSave(widget.user.copyWith(
                        name: _nameCtrl.text, role: _role, 
                        program: (_role == UserRole.admin || _role == UserRole.timbalanPengarahAkademik) ? 'Global' : _program));
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                  },
            icon: const Icon(Icons.save_rounded),
            label: Text(_saving ? 'Menyimpan...' : 'Simpan Perubahan'),
          ),
          const SizedBox(height: 12),

          // Reset password
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              await widget.onResetPassword(widget.user);
            },
            icon: const Icon(Icons.lock_reset_rounded),
            label: const Text('Set Semula Kata Laluan'),
            style: OutlinedButton.styleFrom(
              foregroundColor: EHadirTheme.pending,
              side: const BorderSide(color: EHadirTheme.pending),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    color: EHadirTheme.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: EHadirTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
