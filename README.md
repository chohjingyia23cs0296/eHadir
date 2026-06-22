# eHadir — Attendance & Discipline Management System

**eHadir** is a modern, cross-platform application built with **Flutter** and backed by **Firebase**. It is designed specifically for educational institutions (such as colleges and universities) to streamline schedule creation, track student attendance, and monitor discipline reports in real time.

🌐 **Live Beta:** [Try eHadir Here](https://ehadir-beta.vercel.app/)
---
## Getting Started

## 🚀 Key Features
This project is a starting point for a Flutter application.

*   **📅 Schedule Booking (Muat Naik Jadual):**
    *   Allows class scheduling/booking with built-in conflict prevention.
    *   Restricts double-booking the same room/location at the same date and time.
*   **📋 My Schedule (Jadual Saya):**
    *   Displays a structured agenda of classes assigned to lecturers and students.
    *   Integrates direct actions like taking attendance directly from the schedule card.
*   **✔️ Attendance Tracker (Ambil Kehadiran):**
    *   Allows lecturers to select class slots and log student attendance dynamically.
*   **⚠️ Discipline Reporting (Lapor Disiplin):**
    *   Provides a standardized portal to report student behavioral issues.
    *   Reports are routed directly to the **Program Head (Ketua Program)** and **Department Head (Ketua Jabatan)**.
    *   Supports severity tagging (*Ringan* / *Sederhana* / *Berat*) and detailed issue descriptions.
*   **👤 Role-Based Profile (Profil Saya):**
    *   Displays personal details, role definitions (e.g., *Ketua Program*, *Pensyarah*, *Pelajar*), and program info (e.g., *DMM — Diploma Teknologi Marin*).
A few resources to get you started if this is your first Flutter project:

---
- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

## 🛠️ Tech Stack

*   **Frontend Framework:** [Flutter](https://flutter.dev/) (Dart)
*   **State Management:** [Riverpod](https://riverpod.dev/) (`flutter_riverpod`)
*   **Backend Services:** Google [Firebase](https://firebase.google.com/)
    *   **Firebase Authentication:** Secure user sign-in and session management.
    *   **Cloud Firestore:** Real-time database storing users, classes, schedules, and reports.
*   **Typography:** Google Fonts (`google_fonts`)
*   **Data Visualization:** FL Chart (`fl_chart`) for reporting analytics.

---

## 📂 Project Structure

```text
lib/
├── firebase_options.dart   # Firebase configuration for multi-platform support
├── main.dart               # App entry point
├── theme.dart              # Global UI theme and styling definitions
├── models/                 # Data representation models (User, ClassSlot, Report, etc.)
├── services/               # Firestore, Auth, and external services handlers
├── utils/                  # Helper functions and constants
└── screens/                # UI Screens grouped by feature:
    ├── auth/               # Login and authentication views
    ├── booking/            # Schedule uploading/creation steps
    ├── dashboard/          # Overview dashboards
    ├── lecturer/           # Lecturer-specific functionalities (attendance taking)
    ├── profile/            # User profile pages
    └── app_shell.dart      # Shell containing bottom navigation bar routing
For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
