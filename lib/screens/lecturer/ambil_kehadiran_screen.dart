import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/attendance_record.dart';
import '../../models/lecturer_assignment.dart';
import '../../models/student_model.dart';
import '../../services/absenteeism_warning_service.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';
import '../../services/curriculum_service.dart';
import '../../services/mock_db_service.dart';
import '../../theme.dart';

/// Module 1 — Ambil Kehadiran
///
/// M1..M14 weekly attendance grid for one (subject × class) combination.
/// Lecturers tap a cell to cycle status H → T → MC → CK → blank.
///
/// Two entry modes:
///   • Tap from "Jadual Saya" → opens directly with subjectCode+studentClass.
///   • Bottom-nav "Kehadiran" tab → shows class picker derived from the
///     lecturer's assignments first.
class AmbilKehadiranScreen extends ConsumerStatefulWidget {
  /// Optional class context. When null, the screen renders a class picker.
  final String? subjectCode;
  final String? subjectName;
  final String? studentClass;
  final String? program;

  /// 1-based teaching week (M1 = 1) to open on. When the lecturer taps a class
  /// from the timetable, this is the week they were viewing. Null → defaults to
  /// the current calendar week.
  final int? initialWeek;

  /// Legacy parameter kept for AppShell's deep-link compatibility. Ignored
  /// by the new grid flow.
  final String? initialSlotId;

  const AmbilKehadiranScreen({
    super.key,
    this.subjectCode,
    this.subjectName,
    this.studentClass,
    this.program,
    this.initialWeek,
    this.initialSlotId,
  });

  @override
  ConsumerState<AmbilKehadiranScreen> createState() =>
      _AmbilKehadiranScreenState();
}

class _AmbilKehadiranScreenState extends ConsumerState<AmbilKehadiranScreen> {
  String? _subjectCode;
  String? _subjectName;
  String? _studentClass;
  String? _program;
  int _selectedWeek = 0; // 0-indexed (M1 = 0)

  /// Guards the one-shot "default everyone present" seeding per (class × week).
  String? _seededFor;
  bool _seeding = false;

  @override
  void initState() {
    super.initState();
    _subjectCode = widget.subjectCode;
    _subjectName = widget.subjectName;
    _studentClass = widget.studentClass;
    _program = widget.program;
    // Open on the week the lecturer tapped from the timetable (1-based), else
    // fall back to the current calendar week. Stored 0-indexed (M1 = 0).
    _selectedWeek = ((widget.initialWeek ?? Semester.currentWeek) - 1)
        .clamp(0, ClassAttendance.weeksPerSemester - 1);
  }

  bool get _hasContext =>
      _subjectCode != null &&
      _studentClass != null &&
      _subjectCode!.isNotEmpty &&
      _studentClass!.isNotEmpty;

  /// Marks every blank cell in the active week as "Hadir" so the grid opens
  /// with all students present by default; the lecturer then toggles only the
  /// absentees. Runs once per (class × week); other weeks are left untouched.
  void _scheduleDefaultPresent(
    AttendanceService attendance,
    ClassAttendance current,
    List<StudentModel> students,
  ) {
    if (students.isEmpty) return;
    final key = '${_subjectCode}_${_studentClass}_$_selectedWeek';
    if (_seededFor == key || _seeding) return;
    final hasBlank = students.any((s) =>
        current.statusFor(s.id, _selectedWeek) == AttendanceStatus.belum);
    if (!hasBlank) {
      _seededFor = key; // already complete — don't re-check on every rebuild
      return;
    }
    _seeding = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      var updated = current;
      for (final s in students) {
        if (updated.statusFor(s.id, _selectedWeek) == AttendanceStatus.belum) {
          updated =
              updated.withCell(s.id, _selectedWeek, AttendanceStatus.hadir);
        }
      }
      await attendance.saveClassAttendance(updated);
      _seededFor = key;
      _seeding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ambil Kehadiran'),
      ),
      body: _hasContext ? _buildClassGrid() : _buildClassPicker(),
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  CLASS PICKER (when no context provided)
  // ═════════════════════════════════════════════════════════════

  Widget _buildClassPicker() {
    final user = ref.watch(authProvider).currentUser!;
    final curriculum = ref.read(curriculumServiceProvider);

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: EHadirTheme.surfaceLight,
            borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
            border: Border.all(color: EHadirTheme.divider),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: EHadirTheme.textSecondary, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pilih kelas untuk mengambil kehadiran. '
                  'Anda juga boleh tekan terus pada slot kelas di Jadual Saya.',
                  style: TextStyle(
                      color: EHadirTheme.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<LecturerAssignment>>(
            stream: curriculum.streamAssignmentsForLecturer(user.id),
            builder: (ctx, snap) {
              final list = snap.data ?? const <LecturerAssignment>[];
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (list.isEmpty) {
                return const _EmptyPicker();
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: list.length,
                itemBuilder: (ctx, i) {
                  final a = list[i];
                  return _ClassPickCard(
                    subjectCode: a.subjectCode,
                    subjectName: a.subjectName,
                    studentClass: a.studentClass,
                    program: a.program,
                    onTap: () => setState(() {
                      _subjectCode = a.subjectCode;
                      _subjectName = a.subjectName;
                      _studentClass = a.studentClass;
                      _program = a.program;
                    }),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  GRID
  // ═════════════════════════════════════════════════════════════

  Widget _buildClassGrid() {
    final db = ref.watch(mockDbProvider);
    final auth = ref.watch(authProvider);
    final user = auth.currentUser!;
    // read (not watch): the StreamBuilder + Firestore already drive reactivity,
    // so saves must NOT trigger a parent rebuild that re-subscribes the stream.
    final attendance = ref.read(attendanceServiceProvider);

    final students = db.getStudentsForClass(
      _studentClass!,
      program: _program,
    );

    return StreamBuilder<ClassAttendance?>(
      stream: attendance.streamClassAttendance(
        subjectCode: _subjectCode!,
        studentClass: _studentClass!,
      ),
      builder: (ctx, snap) {
        // Wait for the real document before rendering or seeding. Acting on the
        // empty placeholder during load would overwrite previously-saved weeks.
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final ClassAttendance current = snap.data ??
            ClassAttendance.empty(
              subjectCode: _subjectCode!,
              subjectName: _subjectName ?? _subjectCode!,
              studentClass: _studentClass!,
              program: _program ?? '',
              lecturerId: user.id,
              lecturerName: user.name,
            );

        // Default every student to "Hadir" for the active week so no box is
        // left blank — the lecturer only toggles the absentees afterwards.
        _scheduleDefaultPresent(attendance, current, students);

        return Column(
          children: [
            _ClassHeader(
              subjectCode: _subjectCode!,
              subjectName: _subjectName ?? _subjectCode!,
              studentClass: _studentClass!,
              program: _program ?? '',
              studentCount: students.length,
              onChangeClass: widget.subjectCode == null
                  ? () => setState(() {
                        _subjectCode = null;
                        _subjectName = null;
                        _studentClass = null;
                      })
                  : null,
            ),
            _WeekStrip(
              selected: _selectedWeek,
              current: current,
              studentCount: students.length,
            ),
            _CurrentWeekBanner(week: _selectedWeek + 1),
            const SizedBox(height: 4),
            Expanded(
              child: students.isEmpty
                  ? const _EmptyStudents()
                  : _AttendanceMatrix(
                      students: students,
                      attendance: current,
                      selectedWeek: _selectedWeek,
                      onCellChanged: (s, w, st) async {
                        await attendance.setWeekCell(
                          base: current,
                          studentId: s.id,
                          weekIndex: w,
                          status: st,
                        );
                        // Module 3 — fire absenteeism warnings after the
                        // grid has the latest cell. Build the updated
                        // matrix locally so we don't race the stream.
                        final warner = ref.read(
                            absenteeismWarningServiceProvider);
                        warner.check(
                          attendance: current.withCell(s.id, w, st),
                          studentNames: {
                            for (final stu in students) stu.id: stu.name,
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  CLASS HEADER
// ═══════════════════════════════════════════════════════════════

class _ClassHeader extends StatelessWidget {
  final String subjectCode;
  final String subjectName;
  final String studentClass;
  final String program;
  final int studentCount;
  final VoidCallback? onChangeClass;
  const _ClassHeader({
    required this.subjectCode,
    required this.subjectName,
    required this.studentClass,
    required this.program,
    required this.studentCount,
    required this.onChangeClass,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: EHadirTheme.primaryGradient,
        borderRadius: BorderRadius.circular(EHadirTheme.radiusLg),
        boxShadow: EHadirTheme.glowShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subjectCode,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 2),
                    Text(subjectName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              if (onChangeClass != null)
                IconButton(
                  tooltip: 'Tukar kelas',
                  icon: const Icon(Icons.swap_horiz_rounded,
                      color: Colors.white),
                  onPressed: onChangeClass,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MiniChip(icon: Icons.class_rounded, text: studentClass),
              _MiniChip(icon: Icons.people_rounded, text: '$studentCount pelajar'),
              if (program.isNotEmpty)
                _MiniChip(icon: Icons.school_rounded, text: program.split(' ').first),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MiniChip({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 12),
            const SizedBox(width: 4),
            Text(text,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

// ═══════════════════════════════════════════════════════════════
//  WEEK STRIP
// ═══════════════════════════════════════════════════════════════

class _WeekStrip extends StatelessWidget {
  final int selected;
  final ClassAttendance current;
  final int studentCount;
  const _WeekStrip({
    required this.selected,
    required this.current,
    required this.studentCount,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: ClassAttendance.weeksPerSemester,
        itemBuilder: (ctx, i) {
          final isSelected = i == selected;
          int marked = 0;
          current.weeks.forEach((sid, list) {
            if (i < list.length && list[i].isNotEmpty) marked++;
          });
          final pct = studentCount == 0 ? 0 : (marked * 100 ~/ studentCount);
          final chip = AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 56,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? EHadirTheme.primary
                  : EHadirTheme.surfaceLight,
              borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
              border: Border.all(
                color: isSelected
                    ? EHadirTheme.primary
                    : EHadirTheme.divider,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('M${i + 1}',
                    style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : EHadirTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        height: 1.1)),
                // The active (selected) week is the editable one — badge it
                // "KINI"; the rest show their completion %.
                isSelected
                    ? Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('KINI',
                            style: TextStyle(
                                color: EHadirTheme.primary,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                height: 1.1)),
                      )
                    : Text('$pct%',
                        style: const TextStyle(
                            color: EHadirTheme.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            height: 1.1)),
              ],
            ),
          );
          // Navigation is disabled: the active week is shown crisply, every
          // other week is dimmed and non-interactive (no tap handler).
          return isSelected ? chip : Opacity(opacity: 0.4, child: chip);
        },
      ),
    );
  }
}

/// Slim banner telling the lecturer which week is currently editable.
class _CurrentWeekBanner extends StatelessWidget {
  final int week;
  const _CurrentWeekBanner({required this.week});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: EHadirTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
        border: Border.all(color: EHadirTheme.primary.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded,
              color: EHadirTheme.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sedang menanda kehadiran untuk Minggu $week. '
              'Minggu lain dikunci untuk kelas ini.',
              style: const TextStyle(
                  color: EHadirTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  MATRIX
// ═══════════════════════════════════════════════════════════════

class _AttendanceMatrix extends StatelessWidget {
  final List<StudentModel> students;
  final ClassAttendance attendance;
  final int selectedWeek;
  final Future<void> Function(StudentModel, int, AttendanceStatus)
      onCellChanged;

  const _AttendanceMatrix({
    required this.students,
    required this.attendance,
    required this.selectedWeek,
    required this.onCellChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Container(
            decoration: BoxDecoration(
              color: EHadirTheme.card,
              borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
              border: Border.all(color: EHadirTheme.divider),
            ),
            child: DataTable(
              headingRowColor:
                  WidgetStateProperty.all(EHadirTheme.surfaceLight),
              headingRowHeight: 44,
              dataRowMinHeight: 50,
              dataRowMaxHeight: 50,
              columnSpacing: 14,
              columns: [
                const DataColumn(
                    label: Text('BIL',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 12))),
                const DataColumn(
                    label: Text('NAMA',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 12))),
                for (int i = 0; i < ClassAttendance.weeksPerSemester; i++)
                  DataColumn(
                    label: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: i == selectedWeek
                          ? BoxDecoration(
                              color: EHadirTheme.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            )
                          : null,
                      child: Text('M${i + 1}',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              color: i == selectedWeek
                                  ? EHadirTheme.primary
                                  : EHadirTheme.textPrimary)),
                    ),
                  ),
                const DataColumn(
                    label: Text('%',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 12))),
              ],
              rows: List.generate(students.length, (i) {
                final s = students[i];
                final pct = attendance.percentageFor(s.id);
                final warn = pct > 0 && pct < 80;
                return DataRow(
                  cells: [
                    DataCell(Text('${i + 1}',
                        style: const TextStyle(
                            color: EHadirTheme.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12))),
                    DataCell(SizedBox(
                      width: 240,
                      child: Text(s.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: EHadirTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    )),
                    for (int w = 0; w < ClassAttendance.weeksPerSemester; w++)
                      DataCell(_StatusCell(
                        status: attendance.statusFor(s.id, w),
                        highlight: w == selectedWeek,
                        enabled: w == selectedWeek,
                        onCycle: (next) => onCellChanged(s, w, next),
                      )),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: warn
                              ? EHadirTheme.rejected.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${pct.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: warn
                                ? EHadirTheme.rejected
                                : EHadirTheme.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusCell extends StatelessWidget {
  final AttendanceStatus status;
  final bool highlight;
  final bool enabled;
  final ValueChanged<AttendanceStatus> onCycle;

  const _StatusCell({
    required this.status,
    required this.highlight,
    required this.enabled,
    required this.onCycle,
  });

  // Tap cycle never lands on "belum" so the active week stays fully marked.
  // (Long-press still exposes every status, incl. clearing, as an override.)
  static const _cycle = [
    AttendanceStatus.hadir,
    AttendanceStatus.tidakHadir,
    AttendanceStatus.mc,
    AttendanceStatus.ck,
  ];

  AttendanceStatus _next(AttendanceStatus s) {
    final idx = _cycle.indexOf(s);
    // Unknown/blank → start the cycle at Hadir.
    return _cycle[(idx + 1) % _cycle.length];
  }

  void _openPopup(BuildContext context) async {
    final picked = await showMenu<AttendanceStatus>(
      context: context,
      position: const RelativeRect.fromLTRB(0, 0, 0, 0),
      items: AttendanceStatus.values.map((s) {
        return PopupMenuItem(
          value: s,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(s.icon, color: s.color, size: 14),
              const SizedBox(width: 6),
              Text(s.label,
                  style: TextStyle(color: s.color, fontWeight: FontWeight.w700)),
            ],
          ),
        );
      }).toList(),
    );
    if (picked != null) onCycle(picked);
  }

  @override
  Widget build(BuildContext context) {
    final empty = status == AttendanceStatus.belum;
    // Disabled (non-current week) cells are read-only: muted colours, no taps.
    final box = Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: empty
            ? (enabled
                ? Colors.transparent
                : EHadirTheme.surfaceLight.withValues(alpha: 0.5))
            : status.color.withValues(alpha: enabled ? 0.15 : 0.07),
        border: Border.all(
          color: !enabled
              ? EHadirTheme.divider
              : highlight
                  ? EHadirTheme.primary
                  : status.color.withValues(alpha: empty ? 0.3 : 0.5),
          width: highlight && enabled ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        empty ? '–' : status.code,
        style: TextStyle(
          color: empty
              ? EHadirTheme.textSecondary.withValues(alpha: enabled ? 1 : 0.5)
              : status.color.withValues(alpha: enabled ? 1 : 0.55),
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );

    if (!enabled) return box;

    return GestureDetector(
      onTap: () => onCycle(_next(status)),
      onLongPress: () => _openPopup(context),
      child: box,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  EMPTY STATES
// ═══════════════════════════════════════════════════════════════

class _EmptyPicker extends StatelessWidget {
  const _EmptyPicker();
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fact_check_outlined,
                  size: 64,
                  color: EHadirTheme.textSecondary.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              const Text(
                'Tiada kelas yang ditugaskan kepada anda.\n'
                'Sila tunggu Ketua Program menugaskan subjek.',
                textAlign: TextAlign.center,
                style: TextStyle(color: EHadirTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
}

class _EmptyStudents extends StatelessWidget {
  const _EmptyStudents();
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline_rounded,
                  size: 64,
                  color: EHadirTheme.textSecondary.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              const Text(
                'Tiada pelajar berdaftar untuk kelas ini.',
                textAlign: TextAlign.center,
                style: TextStyle(color: EHadirTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
}

class _ClassPickCard extends StatelessWidget {
  final String subjectCode;
  final String subjectName;
  final String studentClass;
  final String program;
  final VoidCallback onTap;

  const _ClassPickCard({
    required this.subjectCode,
    required this.subjectName,
    required this.studentClass,
    required this.program,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: EHadirTheme.card,
          borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
          border: Border.all(color: EHadirTheme.divider),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: EHadirTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(EHadirTheme.radiusSm),
              ),
              child: const Icon(Icons.book_rounded,
                  color: EHadirTheme.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$subjectCode — $subjectName',
                      style: const TextStyle(
                          color: EHadirTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(studentClass,
                      style: const TextStyle(
                          color: EHadirTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: EHadirTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
