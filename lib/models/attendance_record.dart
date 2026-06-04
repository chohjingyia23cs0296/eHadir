import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Attendance status per the project proposal:
/// H = Hadir (Present), T = Tidak Hadir (Absent),
/// MC = Medical Certificate, CK = Cuti Kebenaran (Official Leave).
enum AttendanceStatus { hadir, tidakHadir, mc, ck, belum }

extension AttendanceStatusX on AttendanceStatus {
  String get code {
    switch (this) {
      case AttendanceStatus.hadir:      return 'H';
      case AttendanceStatus.tidakHadir: return 'T';
      case AttendanceStatus.mc:         return 'MC';
      case AttendanceStatus.ck:         return 'CK';
      case AttendanceStatus.belum:      return '';
    }
  }

  String get label {
    switch (this) {
      case AttendanceStatus.hadir:      return 'Hadir';
      case AttendanceStatus.tidakHadir: return 'Tidak Hadir';
      case AttendanceStatus.mc:         return 'MC';
      case AttendanceStatus.ck:         return 'Cuti Kebenaran';
      case AttendanceStatus.belum:      return 'Belum Diambil';
    }
  }

  Color get color {
    switch (this) {
      case AttendanceStatus.hadir:      return const Color(0xFF10B981); // emerald
      case AttendanceStatus.tidakHadir: return const Color(0xFFEF4444); // red
      case AttendanceStatus.mc:         return const Color(0xFFF59E0B); // amber
      case AttendanceStatus.ck:         return const Color(0xFF3B82F6); // blue
      case AttendanceStatus.belum:      return const Color(0xFF9CA3AF); // gray
    }
  }

  IconData get icon {
    switch (this) {
      case AttendanceStatus.hadir:      return Icons.check_circle_rounded;
      case AttendanceStatus.tidakHadir: return Icons.cancel_rounded;
      case AttendanceStatus.mc:         return Icons.medical_services_rounded;
      case AttendanceStatus.ck:         return Icons.flight_takeoff_rounded;
      case AttendanceStatus.belum:      return Icons.help_outline_rounded;
    }
  }

  static AttendanceStatus fromCode(String? code) {
    switch (code) {
      case 'H':  return AttendanceStatus.hadir;
      case 'T':  return AttendanceStatus.tidakHadir;
      case 'MC': return AttendanceStatus.mc;
      case 'CK': return AttendanceStatus.ck;
      default:   return AttendanceStatus.belum;
    }
  }
}

/// One Firestore document per class slot session.
/// Document id matches the [ClassSlotModel.id] so each slot has at most one record.
class AttendanceSession {
  final String slotId;
  final String subjectName;
  final String program;
  final String lecturerId;
  final String lecturerName;
  final DateTime date;
  final Map<String, AttendanceStatus> records; // studentId → status
  final DateTime? takenAt;
  final DateTime? updatedAt;

  AttendanceSession({
    required this.slotId,
    required this.subjectName,
    required this.program,
    required this.lecturerId,
    required this.lecturerName,
    required this.date,
    required this.records,
    this.takenAt,
    this.updatedAt,
  });

  AttendanceStatus statusFor(String studentId) =>
      records[studentId] ?? AttendanceStatus.belum;

  int countOf(AttendanceStatus s) =>
      records.values.where((v) => v == s).length;

  int get presentCount     => countOf(AttendanceStatus.hadir);
  int get absentCount      => countOf(AttendanceStatus.tidakHadir);
  int get mcCount          => countOf(AttendanceStatus.mc);
  int get ckCount          => countOf(AttendanceStatus.ck);
  int get takenCount       => records.values.where((s) => s != AttendanceStatus.belum).length;

  double presentPercentage(int totalStudents) {
    if (totalStudents == 0) return 0;
    return (presentCount / totalStudents) * 100;
  }

  factory AttendanceSession.empty({
    required String slotId,
    required String subjectName,
    required String program,
    required String lecturerId,
    required String lecturerName,
    required DateTime date,
  }) =>
      AttendanceSession(
        slotId: slotId,
        subjectName: subjectName,
        program: program,
        lecturerId: lecturerId,
        lecturerName: lecturerName,
        date: date,
        records: {},
      );

  AttendanceSession copyWithRecord(String studentId, AttendanceStatus status) {
    final next = Map<String, AttendanceStatus>.from(records);
    if (status == AttendanceStatus.belum) {
      next.remove(studentId);
    } else {
      next[studentId] = status;
    }
    return AttendanceSession(
      slotId: slotId,
      subjectName: subjectName,
      program: program,
      lecturerId: lecturerId,
      lecturerName: lecturerName,
      date: date,
      records: next,
      takenAt: takenAt,
      updatedAt: DateTime.now(),
    );
  }

  factory AttendanceSession.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final raw = (d['records'] as Map<String, dynamic>? ?? {});
    final records = <String, AttendanceStatus>{
      for (final e in raw.entries)
        e.key: AttendanceStatusX.fromCode(e.value?.toString()),
    };
    return AttendanceSession(
      slotId: doc.id,
      subjectName: d['subjectName'] ?? '',
      program: d['program'] ?? '',
      lecturerId: d['lecturerId'] ?? '',
      lecturerName: d['lecturerName'] ?? '',
      date: (d['date'] as Timestamp).toDate(),
      records: records,
      takenAt: (d['takenAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'subjectName': subjectName,
        'program': program,
        'lecturerId': lecturerId,
        'lecturerName': lecturerName,
        'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
        'records': {
          for (final e in records.entries) e.key: e.value.code,
        },
        'takenAt': takenAt != null
            ? Timestamp.fromDate(takenAt!)
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
