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

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  List<AppUser> _activeUsers = [];
  List<AppUser> _pendingUsers = [];
  bool _loading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    final auth = ref.read(authProvider);
    final all = await auth.fetchAllUsers();
    if (mounted) {
      setState(() {
        _activeUsers = all.where((u) => u.isApproved).toList();
        _pendingUsers = all.where((u) => !u.isApproved).toList();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final current = auth.currentUser!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.logout_rounded),
          tooltip: 'Log Keluar',
          onPressed: () => showLogoutConfirmation(context, ref),
        ),
        title: const Text('Admin — Urus Pengguna'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Muat Semula',
            onPressed: _loadUsers,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.hourglass_top_rounded, size: 16),
                  const SizedBox(width: 6),
                  const Text('Menunggu'),
                  if (_pendingUsers.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: EHadirTheme.pending,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_pendingUsers.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('Aktif (${_activeUsers.length})'),
                ],
              ),
            ),
          ],
        ),
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
                      Text(
                        '${_activeUsers.length} aktif · ${_pendingUsers.length} menunggu kelulusan',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _PendingTab(
                        users: _pendingUsers,
                        onRefresh: _loadUsers,
                        onApprove: _approveUser,
                        onReject: _rejectUser,
                      ),
                      _ActiveTab(
                        users: _activeUsers,
                        onRefresh: _loadUsers,
                        onResetPassword: _resetUserPassword,
                        onEdit: _showUserDetail,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveUser(AppUser user) async {
    final auth = ref.read(authProvider);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final err = await auth.approveUser(user.id);
    if (!mounted) return;
    if (err != null) {
      scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(err), backgroundColor: EHadirTheme.rejected));
    } else {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Akaun ${user.name} telah diluluskan.'),
          backgroundColor: EHadirTheme.approved,
        ),
      );
      _loadUsers();
    }
  }

  Future<void> _rejectUser(AppUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EHadirTheme.card,
        title: const Text('Tolak Permohonan',
            style: TextStyle(color: EHadirTheme.textPrimary)),
        content: Text(
          'Adakah anda pasti ingin menolak permohonan ${user.name}?\n\nTindakan ini tidak boleh dibatalkan.',
          style: const TextStyle(color: EHadirTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: EHadirTheme.rejected),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ya, Tolak'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final auth = ref.read(authProvider);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final err = await auth.rejectUser(user.id);
    if (!mounted) return;
    if (err != null) {
      scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(err), backgroundColor: EHadirTheme.rejected));
    } else {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Permohonan ${user.name} telah ditolak.'),
          backgroundColor: EHadirTheme.rejected,
        ),
      );
      _loadUsers();
    }
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
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(EHadirTheme.radiusXl)),
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
                    'Kata laluan sementara: $newPw\nE-mel dihantar ke ${u.email}'),
                backgroundColor: EHadirTheme.accent,
                duration: const Duration(seconds: 6),
              ),
            );
          }
        },
      ),
    );
  }
}

// ─── Pending Tab ─────────────────────────────────────────────

class _PendingTab extends StatelessWidget {
  final List<AppUser> users;
  final VoidCallback onRefresh;
  final Future<void> Function(AppUser) onApprove;
  final Future<void> Function(AppUser) onReject;

  const _PendingTab({
    required this.users,
    required this.onRefresh,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 56, color: EHadirTheme.approved.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            const Text('Tiada permohonan baharu.',
                style: TextStyle(color: EHadirTheme.textSecondary, fontSize: 15)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        itemCount: users.length,
        itemBuilder: (ctx, i) => _PendingUserCard(
          user: users[i],
          onApprove: onApprove,
          onReject: onReject,
        ),
      ),
    );
  }
}

class _PendingUserCard extends StatefulWidget {
  final AppUser user;
  final Future<void> Function(AppUser) onApprove;
  final Future<void> Function(AppUser) onReject;

  const _PendingUserCard(
      {required this.user, required this.onApprove, required this.onReject});

  @override
  State<_PendingUserCard> createState() => _PendingUserCardState();
}

class _PendingUserCardState extends State<_PendingUserCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: EHadirTheme.card,
        borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
        border: Border.all(color: EHadirTheme.pending.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            leading: CircleAvatar(
              backgroundColor: EHadirTheme.pending.withValues(alpha: 0.15),
              child: Text(
                user.name.split(' ').map((w) => w[0]).take(2).join(),
                style: const TextStyle(
                    color: EHadirTheme.pending,
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    _roleBadge(user.role),
                    if (user.program.isNotEmpty &&
                        user.program != 'Global') ...[
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: _busy
                ? const Center(
                    child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ))
                : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            setState(() => _busy = true);
                            await widget.onReject(user);
                          },
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text('Tolak'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: EHadirTheme.rejected,
                            side: const BorderSide(color: EHadirTheme.rejected),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            setState(() => _busy = true);
                            await widget.onApprove(user);
                          },
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('Luluskan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EHadirTheme.approved,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
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

// ─── Active Tab ───────────────────────────────────────────────

class _ActiveTab extends StatelessWidget {
  final List<AppUser> users;
  final VoidCallback onRefresh;
  final Future<void> Function(AppUser) onResetPassword;
  final void Function(AppUser) onEdit;

  const _ActiveTab({
    required this.users,
    required this.onRefresh,
    required this.onResetPassword,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const Center(
        child: Text('Tiada pengguna aktif.',
            style: TextStyle(color: EHadirTheme.textSecondary)),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        itemCount: users.length,
        itemBuilder: (ctx, i) => _ActiveUserCard(
          user: users[i],
          onResetPassword: onResetPassword,
          onEdit: onEdit,
        ),
      ),
    );
  }
}

class _ActiveUserCard extends StatelessWidget {
  final AppUser user;
  final Future<void> Function(AppUser) onResetPassword;
  final void Function(AppUser) onEdit;

  const _ActiveUserCard(
      {required this.user, required this.onResetPassword, required this.onEdit});

  @override
  Widget build(BuildContext context) {
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
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            leading: CircleAvatar(
              backgroundColor: roleColor.withValues(alpha: 0.2),
              child: Text(
                user.name.split(' ').map((w) => w[0]).take(2).join(),
                style: TextStyle(
                    color: roleColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
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
                        color: EHadirTheme.textSecondary.withValues(alpha: 0.7),
                        fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _roleBadge(user.role, roleColor),
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
                  onPressed: () => onResetPassword(user),
                  icon: const Icon(Icons.lock_reset_rounded, size: 18),
                  label: const Text('Reset Password'),
                  style: TextButton.styleFrom(foregroundColor: EHadirTheme.pending),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => onEdit(user),
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

  Widget _roleBadge(UserRole role, Color color) {
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

// ─── User Detail Sheet (active users) ────────────────────────

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
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: EHadirTheme.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),

          const Text('Maklumat Pengguna',
              style: TextStyle(
                  color: EHadirTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),

          _infoRow('E-mel', widget.user.email),
          _infoRow('Kata Laluan', '••••••••  (${widget.user.passwordHash})'),
          const Divider(color: EHadirTheme.divider, height: 28),

          const Text('Nama',
              style: TextStyle(color: EHadirTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: EHadirTheme.textPrimary),
            decoration: const InputDecoration(hintText: 'Nama penuh'),
          ),
          const SizedBox(height: 16),

          const Text('Peranan',
              style: TextStyle(color: EHadirTheme.textSecondary, fontSize: 13)),
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
                style:
                    const TextStyle(color: EHadirTheme.textPrimary, fontSize: 15),
                items: UserRole.values
                    .map((r) => DropdownMenuItem(
                        value: r, child: Text(r.displayName)))
                    .toList(),
                onChanged: (v) => setState(() => _role = v ?? _role),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_role != UserRole.admin &&
              _role != UserRole.timbalanPengarahAkademik) ...[
            const Text('Program',
                style: TextStyle(color: EHadirTheme.textSecondary, fontSize: 13)),
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
                  style: const TextStyle(
                      color: EHadirTheme.textPrimary, fontSize: 15),
                  items: kPrograms
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => setState(() => _program = v ?? _program),
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],

          ElevatedButton.icon(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    await widget.onSave(widget.user.copyWith(
                        name: _nameCtrl.text,
                        role: _role,
                        program: (_role == UserRole.admin ||
                                _role == UserRole.timbalanPengarahAkademik)
                            ? 'Global'
                            : _program));
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                  },
            icon: const Icon(Icons.save_rounded),
            label: Text(_saving ? 'Menyimpan...' : 'Simpan Perubahan'),
          ),
          const SizedBox(height: 12),

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
