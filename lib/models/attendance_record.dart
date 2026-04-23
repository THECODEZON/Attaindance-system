import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceRecord {
  final String id;
  final String uid;
  final String email;
  final String subjectCode;   // e.g. "CS301"
  final String subjectName;   // e.g. "Computer Networks"
  final String slotTime;      // e.g. "09:00 AM - 10:00 AM"
  final double latitude;
  final double longitude;
  final double distanceFromCampus;
  final String wifiName;
  final String wifiBSSID;
  final String status;        // "Present", "Rejected"
  final String rejectionReason;
  final bool isSimulated;
  final DateTime? markedAt;

  AttendanceRecord({
    this.id = '',
    required this.uid,
    required this.email,
    required this.subjectCode,
    required this.subjectName,
    this.slotTime = '',
    required this.latitude,
    required this.longitude,
    required this.distanceFromCampus,
    required this.wifiName,
    required this.wifiBSSID,
    required this.status,
    this.rejectionReason = '',
    this.isSimulated = false,
    this.markedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'subjectCode': subjectCode,
      'subjectName': subjectName,
      'slotTime': slotTime,
      'latitude': latitude,
      'longitude': longitude,
      'distanceFromCampus': distanceFromCampus,
      'wifiName': wifiName,
      'wifiBSSID': wifiBSSID,
      'status': status,
      'rejectionReason': rejectionReason,
      'isSimulated': isSimulated,
      'time': FieldValue.serverTimestamp(),
      'dateKey': _todayKey(), // e.g. "2026-04-22" for one-per-subject-per-day
    };
  }

  factory AttendanceRecord.fromDoc(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    Timestamp? ts = map['time'] as Timestamp?;
    return AttendanceRecord(
      id: doc.id,
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      subjectCode: map['subjectCode'] ?? '',
      subjectName: map['subjectName'] ?? 'General',
      slotTime: map['slotTime'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      distanceFromCampus: (map['distanceFromCampus'] ?? 0.0).toDouble(),
      wifiName: map['wifiName'] ?? 'Unknown',
      wifiBSSID: map['wifiBSSID'] ?? 'Unknown',
      status: map['status'] ?? 'Unknown',
      rejectionReason: map['rejectionReason'] ?? '',
      isSimulated: map['isSimulated'] ?? false,
      markedAt: ts?.toDate(),
    );
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
