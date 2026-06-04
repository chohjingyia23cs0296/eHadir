import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/mock_db_service.dart';
import '../../services/attendance_service.dart';
import '../../services/booking_service.dart';
import '../../models/attendance_record.dart';
import '../../models/class_slot_model.dart';
import '../../models/student_model.dart';
import '../../theme.dart';

/// Module 1 — Taking Attendance
///
/// Lecturers pick one of their class slots, mark every enrolled student
/// as Hadir / Tidak Hadir / MC / CK, then persist the session to Firestore.
class AmbilKehadiranScreen extends ConsumerStatefulWidget {
  final String? initialSlotId;
  const AmbilKehadiranScreen({super.key, this.initialSlotId});

  @override
  ConsumerState<AmbilKehadiranScreen> createState() => _AmbilKehadiranScreenState();
}

class _AmbilKehadiranScreenState extends ConsumerState<AmbilKehadiranScreen> {
  String? _selectedSlotId;
  ClassSlotModel? _selectedSlot;
  AttendanceSession? _workingSession;
  String _searchQuery = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedSlotId = widget.initialSlotId;
    if (_selectedSlotId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadSession(_selectedSlotId!));
    }
  }

  @override
  void didUpdateWidget(covariant AmbilKehadiranScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialSlotId != null && widget.initialSlotId != old.initialSlotId) {
      setState(() => _selectedSlotId = widget.initialSlotId);
      _loadSession(widget.initialSlotId!);
    }
  }

  ClassSlotModel? _resolveSlotLocal(String slotId) {
    final db = ref.read(mockDbProvider);
    final user = ref.read(authProvider).currentUser!;
    final all = db.getClassSlotsForLecturer(user.id);
    try {
      return all.firstWhere((s) => s.id == slotId);
    } catch (_) {
      return null;
    }
  }

  Future<ClassSlotModel?> _resolveSlot(String slotId) async {
    final local = _resolveSlotLocal(slotId);
    if (local != null) return local;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('classSlots')
          .doc(slotId)
          .get();
      if (!doc.exists) return null;
      return ClassSlotModel.fromFirestore(doc);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadSession(String slotId) async {
    final slot = await _resolveSlot(slotId);
    if (slot == null) return;

    final service = ref.read(attendanceServiceProvider);
    final existing = await service.getSession(slotId);

    if (!mounted) return;
    setState(() {
      _selectedSlot = slot;
      _workingSession = existing ??
          AttendanceSession.empty(
            slotId: slot.id,
            subjectName: slot.subjectName,
            program: slot.program,
            lecturerId: slot.lecturerId,
            lecturerName: slot.lecturerName,
            date: slot.date,
          );
    });
  }

  void _setStatus(String studentId, AttendanceStatus status) {
    if (_workingSession == null) return;
    setState(() {
      _workingSession = _workingSession!.copyWithRecord(studentId, status);
    });
  }

  void _markAllPresent(List<StudentModel> students) {
    if (_workingSession == null || students.isEmpty) return;
    setState(() {
      var s = _workingSession!;
      for (final st in students) {
        s = s.copyWithRecord(st.id, AttendanceStatus.hadir);
      }
      _workingSession = s;
    });
  }

  void _clearAll() {
    if (_workingSession == null) return;
    setState(() {
      _workingSession = AttendanceSession.empty(
        slotId: _workingSession!.slotId,
        subjectName: _workingSession!.subjectName,
        program: _workingSession!.program,
        lecturerId: _workingSession!.lecturerId,
        lecturerName: _workingSession!.lecturerName,
        date: _workingSession!.date,
      );
    });
  }

  Future<void> _save(List<StudentModel> students) async {
    if (_workingSession == null) return;
    setState(() => _isSaving = true);

    final service = ref.read(attendanceServiceProvider);
    final db = ref.read(mockDbProvider);

    try {
      await service.saveSession(_workingSession!);

      // Mirror status into the in-memory StudentModel so the legacy
      // weekly view stays consistent until that view is removed.
      _workingSession!.records.forEach((studentId, status) {
        if (status == AttendanceStatus.belum) return;
        db.updateAttendance(
          studentId,
          _workingSession!.subjectName,
          0, // week index unused going forward
          status.code,
        );
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kehadiran disimpan untuk ${_workingSession!.subjectName}.'),
          backgroundColor: EHadirTheme.approved,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan: $e'),
          backgroundColor: EHadirTheme.rejected,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ═════════════════════════════════════════════════════════════
  //  BUILD
  // ═════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(mockDbProvider);
    final auth = ref.watch(authProvider);
    final user = auth.currentUser!;
    final bookingService = ref.read(firestoreBookingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ambil Kehadiran'),
      ),
      body: StreamBuilder<List<ClassSlotModel>>(
        stream: bookingService.streamClassSlotsForLecturer(user.id),
        builder: (context, snap) {
          final remote = snap.data ?? const <ClassSlotModel>[];
          // Merge Firestore + any session-local slots, dedupe by id.
          final localOnly = db
              .getClassSlotsForLecturer(user.id)
              .where((s) => !remote.any((r) => r.id == s.id));
          final slots = [...remote, ...localOnly]
            ..sort((a, b) => a.date.compareTo(b.date));

          return Column(
            children: [
              _SlotPickerCard(
                slots: slots,
                selectedSlotId: _selectedSlotId,
                onChanged: (slotId) {
                  setState(() {
                    _selectedSlotId = slotId;
                    _selectedSlot = null;
                    _workingSession = null;
                  });
                  if (slotId != null) _loadSession(slotId);
                },
              ),
              if (_selectedSlot == null)
                const Expanded(child: _EmptyHint())
              else
                Expanded(child: _buildSessionBody(db, _selectedSlot!)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSessionBody(MockDatabaseService db, ClassSlotModel slot) {
    final allStudents = db.getStudentsForProgram(slot.program);
    final filtered = _searchQuery.isEmpty
        ? allStudents
        : allStudents
            .where((s) => s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                s.id.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    if (_workingSession == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _SessionHeaderCard(slot: slot),
        _SummaryStrip(
          session: _workingSession!,
          totalStudents: allStudents.length,
        ),
        _ActionBar(
          onMarkAllPresent: () => _markAllPresent(allStudents),
          onClear: _clearAll,
          onSearchChanged: (q) => setState(() => _searchQuery = q),
        ),
        Expanded(
          child: allStudents.isEmpty
              ? const _EmptyStudents()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final s = filtered[i];
                    return _StudentRow(
                      student: s,
                      status: _workingSession!.statusFor(s.id),
                      onChanged: (st) => _setStatus(s.id, st),
                    );
                  },
                ),
        ),
        _SaveBar(
          isSaving: _isSaving,
          takenCount: _workingSession!.takenCount,
          totalCount: allStudents.length,
          onSave: () => _save(allStudents),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SLOT PICKER
// ═══════════════════════════════════════════════════════════════

class _SlotPickerCard extends StatelessWidget {
  final List<ClassSlotModel> slots;
  final String? selectedSlotId;
  final ValueChanged<String?> onChanged;

  const _SlotPickerCard({
    required this.slots,
    required this.selectedSlotId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Guard against a selectedSlotId that hasn't loaded into the list yet
    // (DropdownButton asserts when value doesn't match any item).
    final safeValue =
        slots.any((s) => s.id == selectedSlotId) ? selectedSlotId : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      color: EHadirTheme.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih Slot Kelas',
            style: TextStyle(
              color: EHadirTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: EHadirTheme.surfaceLight,
              borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
              border: Border.all(color: EHadirTheme.divider),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: safeValue,
                isExpanded: true,
                hint: const Text(
                  'Sila pilih slot jadual',
                  style: TextStyle(color: EHadirTheme.textSecondary),
                ),
                icon: const Icon(Icons.expand_more_rounded,
                    color: EHadirTheme.textSecondary),
                dropdownColor: EHadirTheme.card,
                items: slots.map((s) {
                  final dateStr = DateFormat('EEE, d MMM').format(s.date);
                  return DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      '${s.subjectName} • $dateStr ${s.timeRangeFormatted}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  HEADER CARD
// ═══════════════════════════════════════════════════════════════

class _SessionHeaderCard extends StatelessWidget {
  final ClassSlotModel slot;
  const _SessionHeaderCard({required this.slot});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(slot.date);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: EHadirTheme.primaryGradient,
        borderRadius: BorderRadius.circular(EHadirTheme.radiusLg),
        boxShadow: EHadirTheme.glowShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            slot.subjectName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            slot.program,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _HeaderChip(icon: Icons.calendar_today_rounded, text: dateStr),
              const SizedBox(width: 8),
              _HeaderChip(
                icon: Icons.access_time_rounded,
                text: slot.timeRangeFormatted,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _HeaderChip(icon: Icons.room_rounded, text: slot.roomId),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HeaderChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SUMMARY STRIP
// ═══════════════════════════════════════════════════════════════

class _SummaryStrip extends StatelessWidget {
  final AttendanceSession session;
  final int totalStudents;
  const _SummaryStrip({required this.session, required this.totalStudents});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _SummaryTile(
            label: 'Hadir',
            count: session.presentCount,
            color: AttendanceStatus.hadir.color,
            icon: AttendanceStatus.hadir.icon,
          ),
          _SummaryTile(
            label: 'Tidak Hadir',
            count: session.absentCount,
            color: AttendanceStatus.tidakHadir.color,
            icon: AttendanceStatus.tidakHadir.icon,
          ),
          _SummaryTile(
            label: 'MC',
            count: session.mcCount,
            color: AttendanceStatus.mc.color,
            icon: AttendanceStatus.mc.icon,
          ),
          _SummaryTile(
            label: 'CK',
            count: session.ckCount,
            color: AttendanceStatus.ck.color,
            icon: AttendanceStatus.ck.icon,
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  const _SummaryTile({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 2),
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  ACTION BAR
// ═══════════════════════════════════════════════════════════════

class _ActionBar extends StatelessWidget {
  final VoidCallback onMarkAllPresent;
  final VoidCallback onClear;
  final ValueChanged<String> onSearchChanged;

  const _ActionBar({
    required this.onMarkAllPresent,
    required this.onClear,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onMarkAllPresent,
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: const Text('Tanda Semua Hadir'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    foregroundColor: AttendanceStatus.hadir.color,
                    side: BorderSide(
                        color: AttendanceStatus.hadir.color.withValues(alpha: 0.5)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reset'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  foregroundColor: EHadirTheme.textSecondary,
                  side: const BorderSide(color: EHadirTheme.divider),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            decoration: InputDecoration(
              hintText: 'Cari nama atau ID pelajar…',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              isDense: true,
              filled: true,
              fillColor: EHadirTheme.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
                borderSide: const BorderSide(color: EHadirTheme.divider),
              ),
            ),
            onChanged: onSearchChanged,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  STUDENT ROW
// ═══════════════════════════════════════════════════════════════

class _StudentRow extends StatelessWidget {
  final StudentModel student;
  final AttendanceStatus status;
  final ValueChanged<AttendanceStatus> onChanged;

  const _StudentRow({
    required this.student,
    required this.status,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EHadirTheme.card,
        borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
        border: Border.all(
          color: status == AttendanceStatus.belum
              ? EHadirTheme.divider
              : status.color.withValues(alpha: 0.4),
          width: status == AttendanceStatus.belum ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: status.color.withValues(alpha: 0.15),
                child: Text(
                  student.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: status.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: const TextStyle(
                        color: EHadirTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      student.id,
                      style: const TextStyle(
                        color: EHadirTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (status != AttendanceStatus.belum)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.code,
                    style: TextStyle(
                      color: status.color,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatusChip(
                status: AttendanceStatus.hadir,
                selected: status == AttendanceStatus.hadir,
                onTap: () => onChanged(AttendanceStatus.hadir),
              ),
              const SizedBox(width: 6),
              _StatusChip(
                status: AttendanceStatus.tidakHadir,
                selected: status == AttendanceStatus.tidakHadir,
                onTap: () => onChanged(AttendanceStatus.tidakHadir),
              ),
              const SizedBox(width: 6),
              _StatusChip(
                status: AttendanceStatus.mc,
                selected: status == AttendanceStatus.mc,
                onTap: () => onChanged(AttendanceStatus.mc),
              ),
              const SizedBox(width: 6),
              _StatusChip(
                status: AttendanceStatus.ck,
                selected: status == AttendanceStatus.ck,
                onTap: () => onChanged(AttendanceStatus.ck),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final AttendanceStatus status;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = status.color;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? c : c.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(EHadirTheme.radiusSm),
            border: Border.all(
              color: selected ? c : c.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            status.code,
            style: TextStyle(
              color: selected ? Colors.white : c,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SAVE BAR
// ═══════════════════════════════════════════════════════════════

class _SaveBar extends StatelessWidget {
  final bool isSaving;
  final int takenCount;
  final int totalCount;
  final VoidCallback onSave;

  const _SaveBar({
    required this.isSaving,
    required this.takenCount,
    required this.totalCount,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = totalCount - takenCount;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: EHadirTheme.card,
          border: Border(top: BorderSide(color: EHadirTheme.divider)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$takenCount / $totalCount ditanda',
                    style: const TextStyle(
                      color: EHadirTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    remaining == 0
                        ? 'Semua pelajar telah ditanda'
                        : '$remaining belum ditanda',
                    style: TextStyle(
                      color: remaining == 0
                          ? EHadirTheme.approved
                          : EHadirTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: isSaving || takenCount == 0 ? null : onSave,
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(isSaving ? 'Menyimpan…' : 'Simpan Kehadiran'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  EMPTY STATES
// ═══════════════════════════════════════════════════════════════

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fact_check_outlined,
              size: 64,
              color: EHadirTheme.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sila pilih slot kelas untuk mula\nmengambil kehadiran.',
              textAlign: TextAlign.center,
              style: TextStyle(color: EHadirTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStudents extends StatelessWidget {
  const _EmptyStudents();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 64,
              color: EHadirTheme.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tiada pelajar berdaftar untuk program ini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: EHadirTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
