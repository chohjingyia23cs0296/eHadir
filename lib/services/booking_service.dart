import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/booking.dart';
import '../models/class_slot_model.dart';
import 'mock_db_service.dart';
import 'package:flutter/material.dart';

final firestoreBookingProvider =
    ChangeNotifierProvider<FirestoreBookingService>((ref) {
  return FirestoreBookingService(mockDb: ref.read(mockDbProvider));
});

/// Firestore-backed booking service for Module 6.
///
/// Provides:
///   • [checkConflict] — queries `bookings` AND `timetableEntries` collections
///                       for time/room overlaps (prevents double-booking)
///   • [saveBooking]   — validates then persists a new booking document
class FirestoreBookingService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final MockDatabaseService mockDb;

  static const String _collection    = 'bookings';
  static const String _classSlots    = 'classSlots';
  static const String _timetableCol  = 'timetableEntries'; // Ketua Jabatan's schedule

  FirestoreBookingService({required this.mockDb});

  // ═══════════════════════════════════════════════════════════
  //  CONFLICT DETECTION ENGINE
  // ═══════════════════════════════════════════════════════════

  /// Queries BOTH `bookings` AND `timetableEntries` collections to check
  /// whether [roomId] is already in use on [date] at an overlapping time.
  ///
  /// Also checks the in-memory mock DB (master timetable + classSlots).
  ///
  /// Returns `true` if any conflict exists using the exact overlap formula:
  ///   `(proposedStart < existingEnd) && (proposedEnd > existingStart)`
  Future<bool> checkConflict(
    String roomId,
    DateTime date,
    int startMin,
    int endMin,
  ) async {
    // Normalise date to midnight for Firestore equality queries
    final dayStart     = DateTime(date.year, date.month, date.day);
    final dayTimestamp = Timestamp.fromDate(dayStart);

    // 1. Check against in-memory master timetable + classSlots
    final isOccupiedInMemory = mockDb.isRoomOccupied(
      roomId,
      date,
      TimeOfDay(hour: startMin ~/ 60, minute: startMin % 60),
      TimeOfDay(hour: endMin   ~/ 60, minute: endMin   % 60),
    );
    if (isOccupiedInMemory) return true;

    try {
      // 2. Check `bookings` collection (other Module 6 bookings)
      final bookingsSnap = await _db
          .collection(_collection)
          .where('roomId', isEqualTo: roomId)
          .where('date', isEqualTo: dayTimestamp)
          .get();

      for (final doc in bookingsSnap.docs) {
        final existingStart = (doc['startTime'] as num).toInt();
        final existingEnd   = (doc['endTime']   as num).toInt();
        if ((startMin < existingEnd) && (endMin > existingStart)) return true;
      }

      // 3. Check `timetableEntries` collection (Ketua Jabatan's schedule)
      //    — uses startMinutes / endMinutes fields on TimetableEntry
      final ttSnap = await _db
          .collection(_timetableCol)
          .where('room', isEqualTo: roomId)
          .where('date', isEqualTo: dayTimestamp)
          .get();

      for (final doc in ttSnap.docs) {
        final existingStart = (doc['startMinutes'] as num?)?.toInt() ?? 0;
        final existingEnd   = (doc['endMinutes']   as num?)?.toInt() ?? 0;
        if ((startMin < existingEnd) && (endMin > existingStart)) return true;
      }

      return false; // No conflict in any source
    } catch (e) {
      debugPrint('FirestoreBookingService.checkConflict error: $e');
      // Fail safe — treat errors as conflicts to prevent accidental double-booking
      return true;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  SAVE BOOKING
  // ═══════════════════════════════════════════════════════════

  /// Checks for conflicts across ALL scheduling sources, then saves the
  /// booking atomically to BOTH `bookings` AND `classSlots` Firestore
  /// collections.
  ///
  /// Writing to both ensures:
  ///   • [WeeklyTimetableScreen] (grid) shows the GANTIAN overlay.
  ///   • [MyTimetableScreen] (card list) shows the replacement in Jadual Saya.
  ///
  /// Throws [BookingConflictException] if the room is already booked.
  Future<void> saveBooking(FirestoreBooking booking) async {
    final hasConflict = await checkConflict(
      booking.roomId,
      booking.date,
      booking.startTime,
      booking.endTime,
    );

    if (hasConflict) {
      throw BookingConflictException(
        'Bilik ${booking.roomId} sudah ditempah pada masa tersebut. '
        'Sila pilih masa atau bilik lain.',
      );
    }

    // Use a batch write to persist to BOTH collections atomically.
    final batch = _db.batch();

    // 1. Write to `bookings` (used by WeeklyTimetableScreen GANTIAN overlay)
    final bookingRef = _db.collection(_collection).doc();
    batch.set(bookingRef, booking.toFirestore());

    // 2. Write a mirror to `classSlots` (used by MyTimetableScreen card list)
    final slotRef = _db.collection(_classSlots).doc();
    batch.set(slotRef, {
      'subjectName':  booking.subjectName,
      'subjectCode':  booking.subjectCode,
      'studentClass': booking.studentClass,
      'roomId':       booking.roomId,
      'lecturerId':   booking.lecturerId,
      'lecturerName': booking.lecturerName,
      'program':      booking.program,
      'date': Timestamp.fromDate(
        DateTime(booking.date.year, booking.date.month, booking.date.day),
      ),
      'startTime': booking.startTime,
      'endTime':   booking.endTime,
      // Link back to the source booking so we can navigate to attendance.
      'bookingRef': bookingRef.id,
      'isReplacement': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════
  //  DELETE BOOKING (Cancellation)
  // ═══════════════════════════════════════════════════════════

  /// Atomically removes a booking from BOTH `bookings` AND `classSlots`
  /// collections so the Jadual Mingguan grid and Jadual Saya card list
  /// both update in real-time.
  ///
  /// [bookingId]   — the document ID in the `bookings` collection.
  /// [classSlotId] — the document ID in the `classSlots` collection.
  Future<void> deleteBooking({
    required String bookingId,
    required String classSlotId,
  }) async {
    final batch = _db.batch();

    if (bookingId.isNotEmpty) {
      batch.delete(_db.collection(_collection).doc(bookingId));
    }
    if (classSlotId.isNotEmpty) {
      batch.delete(_db.collection(_classSlots).doc(classSlotId));
    }

    await batch.commit();
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════
  //  READ BOOKINGS
  // ═══════════════════════════════════════════════════════════

  /// Fetch all bookings for a specific lecturer (one-shot).
  Future<List<FirestoreBooking>> getBookingsForLecturer(String lecturerId) async {
    final snapshot = await _db
        .collection(_collection)
        .where('lecturerId', isEqualTo: lecturerId)
        .get();
    final list = snapshot.docs.map(FirestoreBooking.fromFirestore).toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  /// Real-time stream of all bookings for a specific lecturer.
  /// Used by WeeklyTimetableScreen to overlay replacement bookings on the grid.
  ///
  /// Returns ALL bookings (no date filter) — date scoping is done client-side
  /// in WeeklyTimetableScreen, which filters to the exact Mon–Fri range of
  /// the displayed week. This allows the navigator to show past and future weeks.
  Stream<List<FirestoreBooking>> streamBookingsForLecturer(String lecturerId) {
    return _db
        .collection(_collection)
        .where('lecturerId', isEqualTo: lecturerId)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(FirestoreBooking.fromFirestore).toList();
          list.sort((a, b) => a.date.compareTo(b.date));
          return list;
        });
  }

  // ═══════════════════════════════════════════════════════════
  //  REAL-TIME ROOM AVAILABILITY (Firestore-backed)
  // ═══════════════════════════════════════════════════════════

  /// Emits the list of rooms that are **conflict-free** for the given
  /// [date]/[startMin]/[endMin], queried live from Firestore.
  ///
  /// A room is unavailable if any of the following collections have an
  /// overlapping booking on that date:
  ///   • `bookings`        — Module 6 ad-hoc bookings
  ///   • `timetableEntries`— Ketua Jabatan's regular schedule
  ///
  /// The [allRooms] list comes from [MockDatabaseService.rooms] (the master
  /// room catalogue).  We simply subtract the occupied ones.
  Stream<List<String>> streamOccupiedRooms(
    DateTime date,
    int startMin,
    int endMin,
  ) {
    final dayTimestamp = Timestamp.fromDate(
      DateTime(date.year, date.month, date.day),
    );

    // Merge bookings + timetableEntries snapshots
    final bookingsStream = _db
        .collection(_collection)
        .where('date', isEqualTo: dayTimestamp)
        .snapshots();

    final ttStream = _db
        .collection(_timetableCol)
        .where('date', isEqualTo: dayTimestamp)
        .snapshots();

    // Combine the two live snapshots
    return bookingsStream.asyncExpand((bookingSnap) {
      return ttStream.map((ttSnap) {
        final occupied = <String>{};

        for (final doc in bookingSnap.docs) {
          final eStart = (doc['startTime'] as num?)?.toInt() ?? 0;
          final eEnd   = (doc['endTime']   as num?)?.toInt() ?? 0;
          if ((startMin < eEnd) && (endMin > eStart)) {
            occupied.add(doc['roomId'] as String? ?? '');
          }
        }

        for (final doc in ttSnap.docs) {
          final eStart = (doc['startMinutes'] as num?)?.toInt() ?? 0;
          final eEnd   = (doc['endMinutes']   as num?)?.toInt() ?? 0;
          if ((startMin < eEnd) && (endMin > eStart)) {
            occupied.add(doc['room'] as String? ?? '');
          }
        }

        return occupied.toList();
      });
    });
  }

  /// Streams a full **Room × Period** occupancy matrix for [date].
  ///
  /// Returns `Map<String roomName, Set<int periodIndex>>` where each set
  /// contains the 1-based period indices (1..9) that are occupied for that
  /// room. Combines data from both `bookings` and `timetableEntries`.
  ///
  /// Used by the unified booking grid to show all availability at once.
  Stream<Map<String, Set<int>>> streamOccupiedSlots(DateTime date) {
    final dayTimestamp = Timestamp.fromDate(
      DateTime(date.year, date.month, date.day),
    );

    final bookingsStream = _db
        .collection(_collection)
        .where('date', isEqualTo: dayTimestamp)
        .snapshots();

    final ttStream = _db
        .collection(_timetableCol)
        .where('date', isEqualTo: dayTimestamp)
        .snapshots();

    return bookingsStream.asyncExpand((bookingSnap) {
      return ttStream.map((ttSnap) {
        final matrix = <String, Set<int>>{};

        void addOccupied(String room, int startMin, int endMin) {
          // Convert minutes-from-midnight into period indices (1..9).
          // Period N covers [ (N+7)*60 .. (N+8)*60 ).
          for (int p = 1; p <= 9; p++) {
            final pStart = (p + 7) * 60; // e.g. period 1 = 480 (08:00)
            final pEnd   = (p + 8) * 60; // e.g. period 1 = 540 (09:00)
            // Overlap check: (startMin < pEnd) && (endMin > pStart)
            if (startMin < pEnd && endMin > pStart) {
              matrix.putIfAbsent(room, () => <int>{}).add(p);
            }
          }
        }

        for (final doc in bookingSnap.docs) {
          final room  = doc['roomId'] as String? ?? '';
          final start = (doc['startTime'] as num?)?.toInt() ?? 0;
          final end   = (doc['endTime']   as num?)?.toInt() ?? 0;
          addOccupied(room, start, end);
        }

        for (final doc in ttSnap.docs) {
          final room  = doc['room'] as String? ?? '';
          final start = (doc['startMinutes'] as num?)?.toInt() ?? 0;
          final end   = (doc['endMinutes']   as num?)?.toInt() ?? 0;
          addOccupied(room, start, end);
        }

        // ── Also include in-memory master timetable (recurring weekly) ──
        // The mock DB uses dayOfWeek (1=Mon..5=Fri) to store recurring slots.
        for (final t in mockDb.masterTimetable) {
          if (t.dayOfWeek == date.weekday) {
            final start = t.startTime.hour * 60 + t.startTime.minute;
            final end   = t.endTime.hour   * 60 + t.endTime.minute;
            addOccupied(t.room, start, end);
          }
        }

        // ── Also include in-memory classSlots (same exact date) ──
        for (final s in mockDb.classSlots) {
          if (s.date.year  == date.year  &&
              s.date.month == date.month &&
              s.date.day   == date.day) {
            final start = s.startTime.hour * 60 + s.startTime.minute;
            final end   = s.endTime.hour   * 60 + s.endTime.minute;
            addOccupied(s.roomId, start, end);
          }
        }

        return matrix;

      });
    });
  }

  /// Persist a [ClassSlotModel] to the `classSlots` Firestore collection.
  /// Also stores it in the local mock DB so the conflict engine can detect
  /// it within the same session.
  Future<void> saveClassSlot(ClassSlotModel slot) async {
    await _db.collection(_classSlots).doc(slot.id).set(slot.toFirestore());
    mockDb.uploadClassSlot(slot);
    notifyListeners();
  }

  /// Real-time stream of class slots for a specific lecturer.
  /// Only returns slots from **today onwards** so that past replacement
  /// sessions are automatically hidden from the Jadual Saya card list.
  Stream<List<ClassSlotModel>> streamClassSlotsForLecturer(String lecturerId) {
    final todayTs = Timestamp.fromDate(
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
    );
    return _db
        .collection(_classSlots)
        .where('lecturerId', isEqualTo: lecturerId)
        .where('date', isGreaterThanOrEqualTo: todayTs)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(ClassSlotModel.fromFirestore).toList();
          list.sort((a, b) => a.date.compareTo(b.date));
          return list;
        });
  }

  /// Real-time stream of class slots for a specific program.
  /// Only returns slots from **today onwards**.
  Stream<List<ClassSlotModel>> streamClassSlotsForProgram(String program) {
    final todayTs = Timestamp.fromDate(
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
    );
    return _db
        .collection(_classSlots)
        .where('program', isEqualTo: program)
        .where('date', isGreaterThanOrEqualTo: todayTs)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(ClassSlotModel.fromFirestore).toList();
          list.sort((a, b) => a.date.compareTo(b.date));
          return list;
        });
  }
}

// ═══════════════════════════════════════════════════════════
//  CUSTOM EXCEPTION
// ═══════════════════════════════════════════════════════════

class BookingConflictException implements Exception {
  final String message;
  BookingConflictException(this.message);

  @override
  String toString() => message;
}
