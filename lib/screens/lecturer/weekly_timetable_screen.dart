import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/booking.dart';
import '../../models/timetable_entry.dart';
import '../../services/auth_service.dart';
import '../../services/booking_service.dart';
import '../../services/curriculum_service.dart';
import '../../theme.dart';
import 'ambil_kehadiran_screen.dart';

import 'package:intl/intl.dart';

/// Pensyarah view of the weekly timetable: 5 rows (Mon-Fri) × 9 columns
/// (period 1..9). Overlays Module 6 replacement bookings in amber.
///
/// Now includes week navigation (< >) so lecturers can browse past and
/// future weeks. Replacement bookings are scoped to the specific week
/// being displayed — a June 17th booking only appears in the June 16–20
/// week and automatically disappears in all other weeks.
class WeeklyTimetableScreen extends ConsumerStatefulWidget {
  const WeeklyTimetableScreen({super.key});

  @override
  ConsumerState<WeeklyTimetableScreen> createState() =>
      _WeeklyTimetableScreenState();
}

class _WeeklyTimetableScreenState extends ConsumerState<WeeklyTimetableScreen> {
  /// Offset from the current week. 0 = this week, -1 = last week, +1 = next.
  int _weekOffset = 0;

  /// Compute Monday of the displayed week.
  DateTime get _weekStart {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    return monday.add(Duration(days: _weekOffset * 7));
  }

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 4)); // Friday

  @override
  Widget build(BuildContext context) {
    final user       = ref.watch(authProvider).currentUser!;
    final curriculum = ref.read(curriculumServiceProvider);
    final bookingSvc = ref.read(firestoreBookingProvider);
    final fmt        = DateFormat('dd MMM');
    final isThisWeek = _weekOffset == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadual Mingguan'),
      ),
      body: StreamBuilder<List<TimetableEntry>>(
        stream: curriculum.streamEntriesForLecturer(user.id),
        builder: (ctx, ttSnap) {
          return StreamBuilder<List<FirestoreBooking>>(
            // streamBookingsForLecturer already filters from this week onward;
            // we additionally filter in the grid to the exact displayed week.
            stream: bookingSvc.streamBookingsForLecturer(user.id),
            builder: (ctx2, bookSnap) {
              if (ttSnap.connectionState == ConnectionState.waiting ||
                  bookSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final entries  = ttSnap.data  ?? const <TimetableEntry>[];
              final allBookings = bookSnap.data ?? const <FirestoreBooking>[];

              // ── KEY FIX: Only keep bookings whose exact date falls within
              // the Monday–Friday range of the currently displayed week.
              final weekStart = _weekStart;
              final weekEnd   = _weekEnd;
              final bookings  = allBookings.where((b) {
                final d = DateTime(b.date.year, b.date.month, b.date.day);
                return !d.isBefore(weekStart) && !d.isAfter(weekEnd);
              }).toList();

              return Column(
                children: [
                  _Header(name: user.name, program: user.program),

                  // ── Week Navigator Bar ──
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: EHadirTheme.surfaceLight,
                      borderRadius:
                          BorderRadius.circular(EHadirTheme.radiusMd),
                      border: Border.all(color: EHadirTheme.divider),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back arrow
                        IconButton(
                          icon: const Icon(
                              Icons.chevron_left_rounded,
                              color: EHadirTheme.primary),
                          onPressed: () =>
                              setState(() => _weekOffset--),
                          tooltip: 'Minggu sebelumnya',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),

                        // Week label
                        Column(
                          children: [
                            Text(
                              isThisWeek
                                  ? 'Minggu Ini'
                                  : _weekOffset < 0
                                      ? 'Minggu Lepas (${_weekOffset.abs()} minggu lalu)'
                                      : 'Minggu Hadapan ($_weekOffset minggu akan datang)',
                              style: const TextStyle(
                                color: EHadirTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${fmt.format(weekStart)} – ${fmt.format(weekEnd)}',
                              style: const TextStyle(
                                color: EHadirTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),

                        // Forward arrow
                        IconButton(
                          icon: const Icon(
                              Icons.chevron_right_rounded,
                              color: EHadirTheme.primary),
                          onPressed: () =>
                              setState(() => _weekOffset++),
                          tooltip: 'Minggu seterusnya',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                  // ── Legend ──
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        _LegendDot(
                            color: EHadirTheme.primary,
                            label: 'Jadual Biasa'),
                        const SizedBox(width: 16),
                        _LegendDot(
                            color: const Color(0xFFF59E0B),
                            label: 'Bilik Gantian'),
                        if (bookings.isNotEmpty) ...[  
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${bookings.length} gantian minggu ini',
                              style: const TextStyle(
                                  color: Color(0xFF92400E),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── Grid ──
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        padding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: _TimetableGrid(
                          entries:   entries,
                          bookings:  bookings,
                          weekStart: weekStart,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  LEGEND DOT
// ═══════════════════════════════════════════════════════════

class _LegendDot extends StatelessWidget {
  final Color  color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: EHadirTheme.textSecondary, fontSize: 11)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  HEADER
// ═══════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final String name;
  final String program;
  const _Header({required this.name, required this.program});

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
          const Text('STUDENT\'S TIME TABLE',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 2)),
          const SizedBox(height: 4),
          Text(program,
              style: const TextStyle(color: Colors.white, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_rounded,
                  color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              Text(name,
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(width: 14),
              const Icon(Icons.event_rounded,
                  color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              const Text('SESI JAN - JUN 2026',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  GRID
// ═══════════════════════════════════════════════════════════

/// A "unified cell" used by the grid. Can be either a [TimetableEntry]
/// (regular class) or a [FirestoreBooking] (Module 6 replacement session).
class _UnifiedEntry {
  final TimetableEntry? ttEntry;
  final FirestoreBooking? booking;

  const _UnifiedEntry.fromTimetable(this.ttEntry) : booking = null;
  const _UnifiedEntry.fromBooking(this.booking) : ttEntry = null;

  bool get isBooking => booking != null;

  // Derive day + period range from whichever source is set
  SchoolDay get day {
    if (ttEntry != null) return ttEntry!.day;
    return SchoolDayX.fromInt(booking!.date.weekday);
  }

  int get startPeriod {
    if (ttEntry != null) return ttEntry!.startPeriod;
    return _periodFor(booking!.startTime);
  }

  int get endPeriod {
    if (ttEntry != null) return ttEntry!.endPeriod;
    final endMin = booking!.endTime;
    if (endMin <= 480) return 1;
    if (endMin >= 17 * 60) return 9;
    return (((endMin - 480 - 1) ~/ 60) + 1).clamp(1, 9);
  }

  static int _periodFor(int minutesFromMidnight) {
    if (minutesFromMidnight < 480) return 1;
    if (minutesFromMidnight >= 17 * 60) return 9;
    return ((minutesFromMidnight - 480) ~/ 60) + 1;
  }

  String get id => ttEntry?.id ?? booking!.date.toIso8601String() + booking!.roomId;
}

class _Segment {
  final int start;
  final int end;
  final _UnifiedEntry? entry;
  const _Segment._(this.start, this.end, this.entry);
  factory _Segment.blank(int s, int e) => _Segment._(s, e, null);
  factory _Segment.entry(_UnifiedEntry e, int s, int en) =>
      _Segment._(s, en, e);
  int get span {
    final v = end - start + 1;
    return v < 0 ? 0 : v;
  }
}

class _ClampedEntry {
  final int start;
  final int end;
  final _UnifiedEntry entry;
  const _ClampedEntry(this.start, this.end, this.entry);
}

class _TimetableGrid extends StatelessWidget {
  final List<TimetableEntry>    entries;
  final List<FirestoreBooking>  bookings;
  /// The Monday of the displayed week — used to compute exact dates for each
  /// day column so we can show correct date labels.
  final DateTime weekStart;
  const _TimetableGrid({
    required this.entries,
    required this.bookings,
    required this.weekStart,
  });

  static const double _kDayColW  = 56;
  static const double _kPeriodW  = 130;
  static const double _kHeaderH  = 56;
  static const double _kRowH     = 96;

  List<_UnifiedEntry> _allEntries() {
    return [
      ...entries.map((e) => _UnifiedEntry.fromTimetable(e)),
      ...bookings.map((b) => _UnifiedEntry.fromBooking(b)),
    ];
  }

  List<_Segment> _segmentsForDay(SchoolDay day) {
    int clamp(int v) => v < 1 ? 1 : (v > 9 ? 9 : v);

    final dayEntries = _allEntries()
        .where((e) => e.day == day)
        .map((e) {
          final s  = clamp(e.startPeriod);
          final ee = clamp(e.endPeriod < s ? s : e.endPeriod);
          return _ClampedEntry(s, ee, e);
        })
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    final out = <_Segment>[];
    int cursor = 1;
    for (final ce in dayEntries) {
      if (ce.end < cursor) continue;
      final effectiveStart = ce.start < cursor ? cursor : ce.start;
      if (effectiveStart > cursor) {
        out.add(_Segment.blank(cursor, effectiveStart - 1));
      }
      out.add(_Segment.entry(ce.entry, effectiveStart, ce.end));
      cursor = ce.end + 1;
    }
    if (cursor <= 9) out.add(_Segment.blank(cursor, 9));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: EHadirTheme.card,
        border: Border.all(color: EHadirTheme.divider),
        borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
      ),
      child: Column(
        children: [
          // Header row: period labels
          Row(
            children: [
              const SizedBox(width: _kDayColW, height: _kHeaderH),
              for (final p in Period.all)
                Container(
                  width: _kPeriodW,
                  height: _kHeaderH,
                  decoration: BoxDecoration(
                    color: EHadirTheme.surfaceLight,
                    border: Border(
                      left:   BorderSide(color: EHadirTheme.divider),
                      bottom: BorderSide(color: EHadirTheme.divider),
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${p.index}',
                          style: const TextStyle(
                              color: EHadirTheme.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                      Text(p.label(),
                          style: const TextStyle(
                              color: EHadirTheme.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ),
          // Day rows — now with date labels next to the day name
          for (final day in SchoolDay.values)
            Row(
              children: [
                Container(
                  width: _kDayColW,
                  height: _kRowH,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: EHadirTheme.surfaceLight,
                    border: Border(
                      top: BorderSide(color: EHadirTheme.divider),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(day.short,
                          style: const TextStyle(
                              color: EHadirTheme.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 13)),
                      // Show the actual date for this day column
                      Text(
                        DateFormat('dd/MM').format(
                          weekStart.add(Duration(days: day.index)),
                        ),
                        style: const TextStyle(
                          color: EHadirTheme.textSecondary,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
                ..._segmentsForDay(day)
                    .where((seg) => seg.span > 0)
                    .map((seg) {
                  final w    = _kPeriodW * seg.span;
                  final isBooking = seg.entry?.isBooking ?? false;
                  final cell = Container(
                    width: w,
                    height: _kRowH,
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: EHadirTheme.divider),
                        top:  BorderSide(color: EHadirTheme.divider),
                      ),
                      color: seg.entry == null
                          ? Colors.white
                          : isBooking
                              ? const Color(0xFFFFF9E6) // amber tint for bookings
                              : EHadirTheme.primary.withValues(alpha: 0.06),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: seg.entry == null
                        ? const SizedBox.shrink()
                        : isBooking
                            ? _BookingCell(booking: seg.entry!.booking!)
                            : _EntryCell(entry: seg.entry!.ttEntry!),
                  );
                  if (seg.entry == null) return cell;
                  // Tap any class (regular or replacement) → open Ambil Kehadiran
                  return InkWell(
                    onTap: () {
                      final subjectCode  = isBooking ? seg.entry!.booking!.subjectCode : seg.entry!.ttEntry!.subjectCode;
                      final subjectName  = isBooking ? seg.entry!.booking!.subjectName : seg.entry!.ttEntry!.subjectName;
                      final studentClass = isBooking ? seg.entry!.booking!.studentClass : seg.entry!.ttEntry!.studentClass;
                      final program      = isBooking ? seg.entry!.booking!.program : seg.entry!.ttEntry!.program;
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AmbilKehadiranScreen(
                            subjectCode:  subjectCode,
                            subjectName:  subjectName,
                            studentClass: studentClass,
                            program:      program,
                          ),
                        ),
                      );
                    },
                    child: cell,
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  CELL WIDGETS
// ═══════════════════════════════════════════════════════════

class _EntryCell extends StatelessWidget {
  final TimetableEntry entry;
  const _EntryCell({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (entry.room.isNotEmpty)
          Text(entry.room.toUpperCase(),
              style: const TextStyle(
                  color: EHadirTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(entry.subjectCode,
                    style: const TextStyle(
                        color: EHadirTheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(entry.studentClass,
                    style: const TextStyle(
                        color: EHadirTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        Text(entry.lecturerName.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: EHadirTheme.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// Amber-themed cell for Module 6 replacement bookings.
class _BookingCell extends StatelessWidget {
  final FirestoreBooking booking;
  const _BookingCell({required this.booking});

  @override
  Widget build(BuildContext context) {
    String fmt(int mins) {
      final h = (mins ~/ 60).toString().padLeft(2, '0');
      final m = (mins % 60).toString().padLeft(2, '0');
      return '$h:$m';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "GANTIAN" badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text('GANTIAN',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(booking.subjectName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF92400E),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(booking.roomId,
                    style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 9,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        Text('${fmt(booking.startTime)}–${fmt(booking.endTime)}',
            style: const TextStyle(
                color: Color(0xFFA16207), fontSize: 9)),
      ],
    );
  }
}
