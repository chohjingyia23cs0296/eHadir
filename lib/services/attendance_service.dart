import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attendance_record.dart';

/// Firestore-backed service for the Taking Attendance module.
///
/// Storage layout — one document per class slot session:
///   attendanceSessions/{slotId}
///     subjectName, program, lecturerId, lecturerName, date,
///     records: { studentId: 'H' | 'T' | 'MC' | 'CK' },
///     takenAt, updatedAt
class AttendanceService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'attendanceSessions';

  // ─── Read ─────────────────────────────────────────────────

  /// Live stream of a single session for [slotId]. Emits `null`
  /// if no record exists yet.
  Stream<AttendanceSession?> streamSession(String slotId) {
    return _db.collection(_collection).doc(slotId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AttendanceSession.fromFirestore(doc);
    });
  }

  Future<AttendanceSession?> getSession(String slotId) async {
    final doc = await _db.collection(_collection).doc(slotId).get();
    if (!doc.exists) return null;
    return AttendanceSession.fromFirestore(doc);
  }

  /// All recorded sessions for a lecturer (used by the lecturer history view).
  Stream<List<AttendanceSession>> streamSessionsForLecturer(String lecturerId) {
    return _db
        .collection(_collection)
        .where('lecturerId', isEqualTo: lecturerId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(AttendanceSession.fromFirestore).toList());
  }

  /// All sessions for a given program (Head of Program reporting feed).
  Stream<List<AttendanceSession>> streamSessionsForProgram(String program) {
    return _db
        .collection(_collection)
        .where('program', isEqualTo: program)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(AttendanceSession.fromFirestore).toList());
  }

  // ─── Write ────────────────────────────────────────────────

  /// Upsert an attendance session document.
  Future<void> saveSession(AttendanceSession session) async {
    try {
      await _db
          .collection(_collection)
          .doc(session.slotId)
          .set(session.toFirestore(), SetOptions(merge: true));
      notifyListeners();
    } catch (e) {
      debugPrint('AttendanceService.saveSession error: $e');
      rethrow;
    }
  }

  /// Mark every student in [studentIds] as [status] for [slotId] in one write.
  Future<void> markAll({
    required AttendanceSession base,
    required Iterable<String> studentIds,
    required AttendanceStatus status,
  }) async {
    final next = Map<String, AttendanceStatus>.from(base.records);
    for (final id in studentIds) {
      if (status == AttendanceStatus.belum) {
        next.remove(id);
      } else {
        next[id] = status;
      }
    }
    final updated = AttendanceSession(
      slotId: base.slotId,
      subjectName: base.subjectName,
      program: base.program,
      lecturerId: base.lecturerId,
      lecturerName: base.lecturerName,
      date: base.date,
      records: next,
      takenAt: base.takenAt,
      updatedAt: DateTime.now(),
    );
    await saveSession(updated);
  }

  // ─── Aggregation helpers (Reporting Module) ───────────────

  /// Computes per-student attendance percentage across every recorded session
  /// for a program. Only counts sessions where the student has a marked status.
  Future<Map<String, double>> programPercentagesByStudent(String program) async {
    final snap = await _db
        .collection(_collection)
        .where('program', isEqualTo: program)
        .get();

    final present = <String, int>{};
    final taken = <String, int>{};

    for (final doc in snap.docs) {
      final session = AttendanceSession.fromFirestore(doc);
      session.records.forEach((sid, status) {
        if (status == AttendanceStatus.belum) return;
        taken[sid] = (taken[sid] ?? 0) + 1;
        if (status == AttendanceStatus.hadir) {
          present[sid] = (present[sid] ?? 0) + 1;
        }
      });
    }

    return {
      for (final sid in taken.keys)
        sid: taken[sid] == 0 ? 0 : (present[sid] ?? 0) / taken[sid]! * 100,
    };
  }
}

final attendanceServiceProvider =
    ChangeNotifierProvider<AttendanceService>((ref) => AttendanceService());
