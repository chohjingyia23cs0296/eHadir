import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  pensyarah,    // Lecturer
  admin,
  ketuaProgram,
  ketuaJabatan,
  timbalanPengarahAkademik,
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.pensyarah:
        return 'Pensyarah';
      case UserRole.admin:
        return 'Admin';
      case UserRole.ketuaProgram:
        return 'Ketua Program';
      case UserRole.ketuaJabatan:
        return 'Ketua Jabatan';
      case UserRole.timbalanPengarahAkademik:
        return 'Timbalan Pengarah Akademik';
    }
  }

  static UserRole fromString(String s) {
    switch (s) {
      case 'pensyarah':
        return UserRole.pensyarah;
      case 'admin':
        return UserRole.admin;
      case 'ketuaProgram':
        return UserRole.ketuaProgram;
      case 'ketuaJabatan':
        return UserRole.ketuaJabatan;
      case 'timbalanPengarahAkademik':
        return UserRole.timbalanPengarahAkademik;
      default:
        return UserRole.pensyarah;
    }
  }
}

// Keep old alias so existing code compiles without changes
// ignore: camel_case_types
typedef lecturer = UserRole;

const kPrograms = [
  'DCB — Diploma Lanjutan Kompetensi Elektrik (Penjanaan)',
  'DCP — Diploma Kompetensi Elektrik (Kuasa)',
  'DED — Diploma Teknologi Kejuruteraan Elektrik (Domestik Industri)',
  'DEK — Diploma Teknologi Pembuatan Elektronik',
  'DGM — Diploma Teknologi Mekatronik',
  'DGS — Diploma Teknologi Kejuruteraan Gas',
  'DMM — Diploma Teknologi Marin',
  'DPP — Diploma Teknologi Kejuruteraan Penyamanan Udara dan Penyejukan',
  'IMF — Diploma Industri Siapan Logam',
  'ITW — Diploma Kompetensi Kimpalan',
  'SLR — Sijil Teknologi Kejuruteraan Lukisan dan Rekabentuk',
  'SMI — Sijil Teknologi Kejuruteraan Mekanik Industri',
  'SMK — Sijil Teknologi Kejuruteraan Mekatronik',
  'SMM — Sijil Teknologi Kejuruteraan Marin',
];

String getSafeProgram(String program) {
  if (program.isEmpty || program == 'Global') return kPrograms.first;
  if (kPrograms.contains(program)) return program;
  
  try {
    return kPrograms.firstWhere((p) => p.startsWith(program));
  } catch (_) {
    return kPrograms.first;
  }
}

class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String program;       // e.g. "DGS"
  final String passwordHash;  // sha256 hex or '••••••••' placeholder
  final bool isApproved;      // false = pending admin approval

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.program = '',
    this.passwordHash = '••••••••',
    this.isApproved = true,   // default true keeps existing accounts active
  });

  // ─── Firestore ────────────────────────────────────────────

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AppUser(
      id: doc.id,
      name: d['name'] ?? '',
      email: d['email'] ?? '',
      role: UserRoleExtension.fromString(d['role'] ?? 'pensyarah'),
      program: d['program'] ?? '',
      passwordHash: d['passwordHash'] ?? '••••••••',
      isApproved: (d['isApproved'] as bool?) ?? true, // missing field → legacy account → approved
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'email': email,
        'role': role.name,
        'program': program,
        'passwordHash': passwordHash,
        'isApproved': isApproved,
      };

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    String? program,
    String? passwordHash,
    bool? isApproved,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      program: program ?? this.program,
      passwordHash: passwordHash ?? this.passwordHash,
      isApproved: isApproved ?? this.isApproved,
    );
  }
}
