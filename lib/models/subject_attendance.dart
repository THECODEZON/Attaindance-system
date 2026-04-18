class SubjectAttendance {
  final String subjectName;
  final int present;
  final int absent;

  SubjectAttendance({
    required this.subjectName,
    required this.present,
    required this.absent,
  });

  double get percentage => total == 0 ? 0 : (present / total) * 100;
  int get total => present + absent;

  static List<SubjectAttendance> mockList() {
    return [
      SubjectAttendance(subjectName: "Computer Networks", present: 24, absent: 2),
      SubjectAttendance(subjectName: "Operating Systems", present: 18, absent: 5),
      SubjectAttendance(subjectName: "DBMS", present: 22, absent: 1),
      SubjectAttendance(subjectName: "Software Engineering", present: 20, absent: 3),
      SubjectAttendance(subjectName: "Mobile Computing", present: 15, absent: 0),
    ];
  }
}
