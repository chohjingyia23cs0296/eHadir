import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../theme.dart';

// Import dashboards
import 'dashboard/admin_dashboard_screen.dart';
import 'dashboard/ketua_program_dashboard_screen.dart';
import 'dashboard/ketua_jabatan_dashboard_screen.dart';
import 'dashboard/tpa_dashboard_screen.dart';
import 'dashboard/pensyarah_dashboard_screen.dart';

// Import modules
import 'lecturer/ambil_kehadiran_screen.dart';
import 'lecturer/lapor_disiplin_screen.dart';
import 'lecturer/my_timetable_screen.dart';
import 'profile/profile_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  final AppUser currentUser;
  const AppShell({super.key, required this.currentUser});

  @override
  ConsumerState<AppShell> createState() => AppShellState();
}

class AppShellState extends ConsumerState<AppShell> {
  int _currentIndex = 0;
  String? _attendanceSlotId;

  void navigateToTab(int index) {
    if (index >= 0 && index < _buildScreens().length) {
      setState(() => _currentIndex = index);
    }
  }

  void navigateToAttendanceTab(String slotId) {
    setState(() {
      _attendanceSlotId = slotId;
      _currentIndex = 2;
    });
  }

  List<Widget> _buildScreens() {
    // 0: Utama, 1: Jadual, 2: Kehadiran, 3: Laporan, 4: Profil/Tempah Bilik
    Widget utama;
    switch (widget.currentUser.role) {
      case UserRole.admin:
        utama = const AdminDashboardScreen();
        break;
      case UserRole.ketuaProgram:
        utama = const KetuaProgramDashboardScreen();
        break;
      case UserRole.ketuaJabatan:
        utama = const KetuaJabatanDashboardScreen();
        break;
      case UserRole.timbalanPengarahAkademik:
        utama = const TPADashboardScreen();
        break;
      case UserRole.pensyarah:
        utama = const PensyarahDashboardScreen();
        break;
    }

    return [
      utama,
      MyTimetableScreen(onTakeAttendance: navigateToAttendanceTab), // Jadual
      AmbilKehadiranScreen(
        key: ValueKey(_attendanceSlotId ?? 'attendance-tab'),
        initialSlotId: _attendanceSlotId,
      ), // Kehadiran
      const LaporDisiplinScreen(), // Laporan
      const ProfileScreen(), // Profil
    ];
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => navigateToTab(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? EHadirTheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? EHadirTheme.primary : EHadirTheme.textSecondary,
              size: 22,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: isSelected
                  ? Row(
                      children: [
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: const TextStyle(
                            color: EHadirTheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = _buildScreens();
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: EHadirTheme.divider),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, 'Utama'),
              _buildNavItem(1, Icons.calendar_month_rounded, 'Jadual'),
              _buildNavItem(2, Icons.fact_check_rounded, 'Kehadiran'),
              _buildNavItem(3, Icons.bar_chart_rounded, 'Laporan'),
              _buildNavItem(4, Icons.person_rounded, 'Profil'),
            ],
          ),
        ),
      ),
    );
  }
}
