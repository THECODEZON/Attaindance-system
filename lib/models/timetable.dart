/// Represents a single class period in the timetable
class ClassSlot {
  final String subjectCode;
  final String subjectName;
  final String faculty;
  final String room;
  final int startHour;   // 24h format, e.g. 9 = 9:00 AM
  final int startMinute;
  final int endHour;
  final int endMinute;

  const ClassSlot({
    required this.subjectCode,
    required this.subjectName,
    required this.faculty,
    required this.room,
    required this.startHour,
    this.startMinute = 0,
    required this.endHour,
    this.endMinute = 0,
  });

  String get timeRange {
    String fmt(int h, int m) {
      final period = h >= 12 ? 'PM' : 'AM';
      final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      return '${hour.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
    }
    return '${fmt(startHour, startMinute)} - ${fmt(endHour, endMinute)}';
  }

  /// Check if this class is currently active
  bool isActive(DateTime now) {
    final startMins = startHour * 60 + startMinute;
    final endMins = endHour * 60 + endMinute;
    final nowMins = now.hour * 60 + now.minute;
    return nowMins >= startMins && nowMins < endMins;
  }

  /// Check if this class is upcoming (within the next class-length window)
  bool isUpcoming(DateTime now) {
    final startMins = startHour * 60 + startMinute;
    final nowMins = now.hour * 60 + now.minute;
    return startMins > nowMins && (startMins - nowMins) <= 60;
  }

  /// Check if this class already ended today
  bool hasEnded(DateTime now) {
    final endMins = endHour * 60 + endMinute;
    final nowMins = now.hour * 60 + now.minute;
    return nowMins >= endMins;
  }
}

/// Full weekly timetable for B.Tech CSE students
class Timetable {
  // Day names: 1=Monday ... 7=Sunday (from DateTime.weekday)
  static const Map<int, String> dayNames = {
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
    7: 'Sunday',
  };

  /// All CS subjects
  static const List<String> allSubjects = [
    'Computer Networks',
    'Operating Systems',
    'DBMS',
    'Software Engineering',
    'Mobile Computing',
  ];

  static const List<String> allSubjectCodes = [
    'CS301',
    'CS302',
    'CS303',
    'CS304',
    'CS305',
  ];

  /// Weekly schedule — maps weekday number to list of ClassSlots
  static final Map<int, List<ClassSlot>> schedule = {
    // Monday
    1: [
      const ClassSlot(subjectCode: 'CS301', subjectName: 'Computer Networks', faculty: 'Dr. Sharma', room: 'LH-301', startHour: 9, endHour: 10),
      const ClassSlot(subjectCode: 'CS302', subjectName: 'Operating Systems', faculty: 'Dr. Verma', room: 'LH-302', startHour: 10, endHour: 11),
      const ClassSlot(subjectCode: 'CS303', subjectName: 'DBMS', faculty: 'Dr. Gupta', room: 'LH-303', startHour: 11, endHour: 12),
      const ClassSlot(subjectCode: 'CS304', subjectName: 'Software Engineering', faculty: 'Prof. Singh', room: 'LH-304', startHour: 13, endHour: 14),
      const ClassSlot(subjectCode: 'CS305', subjectName: 'Mobile Computing', faculty: 'Dr. Kumar', room: 'Lab-201', startHour: 14, endHour: 15),
    ],
    // Tuesday
    2: [
      const ClassSlot(subjectCode: 'CS302', subjectName: 'Operating Systems', faculty: 'Dr. Verma', room: 'LH-302', startHour: 9, endHour: 10),
      const ClassSlot(subjectCode: 'CS303', subjectName: 'DBMS', faculty: 'Dr. Gupta', room: 'LH-303', startHour: 10, endHour: 11),
      const ClassSlot(subjectCode: 'CS301', subjectName: 'Computer Networks', faculty: 'Dr. Sharma', room: 'LH-301', startHour: 11, endHour: 12),
      const ClassSlot(subjectCode: 'CS305', subjectName: 'Mobile Computing', faculty: 'Dr. Kumar', room: 'Lab-201', startHour: 13, endHour: 14),
      const ClassSlot(subjectCode: 'CS304', subjectName: 'Software Engineering', faculty: 'Prof. Singh', room: 'LH-304', startHour: 14, endHour: 15),
    ],
    // Wednesday
    3: [
      const ClassSlot(subjectCode: 'CS303', subjectName: 'DBMS', faculty: 'Dr. Gupta', room: 'LH-303', startHour: 9, endHour: 10),
      const ClassSlot(subjectCode: 'CS301', subjectName: 'Computer Networks', faculty: 'Dr. Sharma', room: 'Lab-101', startHour: 10, endHour: 11),
      const ClassSlot(subjectCode: 'CS304', subjectName: 'Software Engineering', faculty: 'Prof. Singh', room: 'LH-304', startHour: 11, endHour: 12),
      const ClassSlot(subjectCode: 'CS302', subjectName: 'Operating Systems', faculty: 'Dr. Verma', room: 'LH-302', startHour: 13, endHour: 14),
      const ClassSlot(subjectCode: 'CS305', subjectName: 'Mobile Computing', faculty: 'Dr. Kumar', room: 'Lab-201', startHour: 14, endHour: 15),
    ],
    // Thursday
    4: [
      const ClassSlot(subjectCode: 'CS305', subjectName: 'Mobile Computing', faculty: 'Dr. Kumar', room: 'Lab-201', startHour: 9, endHour: 10),
      const ClassSlot(subjectCode: 'CS304', subjectName: 'Software Engineering', faculty: 'Prof. Singh', room: 'LH-304', startHour: 10, endHour: 11),
      const ClassSlot(subjectCode: 'CS302', subjectName: 'Operating Systems', faculty: 'Dr. Verma', room: 'Lab-102', startHour: 11, endHour: 12),
      const ClassSlot(subjectCode: 'CS301', subjectName: 'Computer Networks', faculty: 'Dr. Sharma', room: 'LH-301', startHour: 13, endHour: 14),
      const ClassSlot(subjectCode: 'CS303', subjectName: 'DBMS', faculty: 'Dr. Gupta', room: 'LH-303', startHour: 14, endHour: 15),
    ],
    // Friday
    5: [
      const ClassSlot(subjectCode: 'CS301', subjectName: 'Computer Networks', faculty: 'Dr. Sharma', room: 'LH-301', startHour: 9, endHour: 10),
      const ClassSlot(subjectCode: 'CS305', subjectName: 'Mobile Computing', faculty: 'Dr. Kumar', room: 'Lab-201', startHour: 10, endHour: 11),
      const ClassSlot(subjectCode: 'CS303', subjectName: 'DBMS', faculty: 'Dr. Gupta', room: 'Lab-103', startHour: 11, endHour: 12),
      const ClassSlot(subjectCode: 'CS304', subjectName: 'Software Engineering', faculty: 'Prof. Singh', room: 'LH-304', startHour: 13, endHour: 14),
      const ClassSlot(subjectCode: 'CS302', subjectName: 'Operating Systems', faculty: 'Dr. Verma', room: 'LH-302', startHour: 14, endHour: 15),
    ],
    // Saturday — half day
    6: [
      const ClassSlot(subjectCode: 'CS303', subjectName: 'DBMS', faculty: 'Dr. Gupta', room: 'LH-303', startHour: 9, endHour: 10),
      const ClassSlot(subjectCode: 'CS301', subjectName: 'Computer Networks', faculty: 'Dr. Sharma', room: 'LH-301', startHour: 10, endHour: 11),
      const ClassSlot(subjectCode: 'CS302', subjectName: 'Operating Systems', faculty: 'Dr. Verma', room: 'LH-302', startHour: 11, endHour: 12),
    ],
    // Sunday — no classes
    7: [],
  };

  /// Get today's classes
  static List<ClassSlot> getTodayClasses() {
    final weekday = DateTime.now().weekday;
    return schedule[weekday] ?? [];
  }

  /// Get the currently active class (if any)
  static ClassSlot? getCurrentClass() {
    final now = DateTime.now();
    final todayClasses = getTodayClasses();
    for (final slot in todayClasses) {
      if (slot.isActive(now)) return slot;
    }
    return null;
  }

  /// Get the next upcoming class
  static ClassSlot? getNextClass() {
    final now = DateTime.now();
    final todayClasses = getTodayClasses();
    for (final slot in todayClasses) {
      if (slot.isUpcoming(now)) return slot;
    }
    return null;
  }

  /// Get today's day name
  static String getTodayName() {
    return dayNames[DateTime.now().weekday] ?? 'Unknown';
  }
}
