import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../app_shell.dart';
import '../booking/create_booking_screen.dart';
import '../lecturer/ambil_kehadiran_screen.dart';
import '../../utils/dialogs.dart';

/// Pensyarah (Lecturer) Dashboard — the "shell" for teammates.
///
/// Module 1-5 cards show a placeholder SnackBar message.
/// Module 6 "Tempah Bilik" navigates to the full CreateBookingScreen.
class PensyarahDashboardScreen extends ConsumerWidget {
  const PensyarahDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final current = auth.currentUser!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Log Keluar',
          onPressed: () => showLogoutConfirmation(context, ref),
        ),
        title: Text('Pensyarah — ${current.name.split(' ').first}'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: EHadirTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(EHadirTheme.radiusLg),
                  boxShadow: EHadirTheme.glowShadow,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: Text(
                        current.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Selamat Datang,',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 14)),
                          Text(
                            current.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Menu Utama',
                style: TextStyle(
                  color: EHadirTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              // 2×3 Grid — 5 placeholders + 1 real module
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.95,
                  children: [
                    // ── Module 5: My Timetable (Placeholder) ──
                    _MenuCard(
                      title: 'Jadual Saya',
                      subtitle: 'Module 5',
                      icon: Icons.calendar_month_rounded,
                      color: EHadirTheme.primary,
                      onTap: () => _showPlaceholder(context, 5),
                    ),

                    // ═══ MODULE 1: AMBIL KEHADIRAN (ACTIVE) ═══
                    _MenuCard(
                      title: 'Ambil Kehadiran',
                      subtitle: 'Module 1',
                      icon: Icons.fact_check_rounded,
                      color: EHadirTheme.approved,
                      isHighlighted: true,
                      onTap: () {
                        // Prefer switching the bottom-nav tab so the state
                        // stays consistent with deep-links from the timetable.
                        final shell =
                            context.findAncestorStateOfType<AppShellState>();
                        if (shell != null) {
                          shell.navigateToTab(2);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AmbilKehadiranScreen()),
                          );
                        }
                      },
                    ),

                    // ── Module 2: Lapor Disiplin (Placeholder) ──
                    _MenuCard(
                      title: 'Lapor Disiplin',
                      subtitle: 'Module 2',
                      icon: Icons.gavel_rounded,
                      color: EHadirTheme.rejected,
                      onTap: () => _showPlaceholder(context, 2),
                    ),

                    // ── Module 3: Pengurusan Pelajar (Placeholder) ──
                    _MenuCard(
                      title: 'Pengurusan Pelajar',
                      subtitle: 'Module 3',
                      icon: Icons.people_alt_rounded,
                      color: EHadirTheme.pending,
                      onTap: () => _showPlaceholder(context, 3),
                    ),

                    // ── Module 4: Upload Schedule (Placeholder) ──
                    _MenuCard(
                      title: 'Muat Naik Jadual',
                      subtitle: 'Module 4',
                      icon: Icons.upload_file_rounded,
                      color: const Color(0xFF7C4DFF),
                      onTap: () => _showPlaceholder(context, 4),
                    ),

                    // ═══ MODULE 6: BOOK REPLACEMENT ROOM (ACTIVE) ═══
                    _MenuCard(
                      title: 'Tempah Bilik',
                      subtitle: 'Module 6',
                      icon: Icons.add_location_alt_rounded,
                      color: EHadirTheme.accent,
                      isHighlighted: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CreateBookingScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPlaceholder(BuildContext context, int moduleNumber) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Module $moduleNumber is pending implementation by teammate.',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: EHadirTheme.pending,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isHighlighted;

  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isHighlighted
          ? EHadirTheme.accent.withValues(alpha: 0.08)
          : EHadirTheme.card,
      borderRadius: BorderRadius.circular(EHadirTheme.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.1),
        highlightColor: color.withValues(alpha: 0.05),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isHighlighted ? EHadirTheme.accent : EHadirTheme.divider,
              width: isHighlighted ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(EHadirTheme.radiusLg),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 36),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: EHadirTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: color.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
