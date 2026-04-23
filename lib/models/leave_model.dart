import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveRequest {
  final String id;
  final String uid;
  final String studentName;
  final String dateKey; // e.g. 2026-04-22
  final String reason;
  final String subjectCode; // "Full Day" or a specific code like "CS301"
  final String status; // "Pending", "Approved", "Rejected"
  final String? documentUrl; // URL of uploaded proof image
  final DateTime appliedAt;

  LeaveRequest({
    this.id = '',
    required this.uid,
    required this.studentName,
    required this.dateKey,
    required this.reason,
    required this.subjectCode,
    this.status = 'Pending',
    this.documentUrl,
    DateTime? appliedAt,
  }) : appliedAt = appliedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'studentName': studentName,
      'dateKey': dateKey,
      'reason': reason,
      'subjectCode': subjectCode,
      'status': status,
      'documentUrl': documentUrl,
      'appliedAt': appliedAt,
    };
  }

  factory LeaveRequest.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LeaveRequest(
      id: doc.id,
      uid: data['uid'] ?? '',
      studentName: data['studentName'] ?? '',
      dateKey: data['dateKey'] ?? '',
      reason: data['reason'] ?? '',
      subjectCode: data['subjectCode'] ?? 'Full Day',
      status: data['status'] ?? 'Pending',
      documentUrl: data['documentUrl'],
      appliedAt: (data['appliedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
