import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/leave_model.dart';

class LeaveService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Submit a Leave Request ──────────────────────────────────────────
  Future<Map<String, dynamic>> submitLeaveRequest(LeaveRequest request) async {
    try {
      await _firestore.collection('leave_requests').add(request.toMap());
      return {'success': true, 'message': 'Leave request submitted successfully.'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to submit request: $e'};
    }
  }

  // ─── Get User Leave Requests ───────────────────────────────────────
  Stream<List<LeaveRequest>> getUserLeaveRequests(String uid) {
    return _firestore
        .collection('leave_requests')
        .where('uid', isEqualTo: uid)
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => LeaveRequest.fromDoc(doc)).toList());
  }

  // ─── Delete a Leave Request (if pending) ───────────────────────────
  Future<void> deleteRequest(String id) async {
    await _firestore.collection('leave_requests').doc(id).delete();
  }

  // ─── ADMIN: Get All Pending Leaves (Legacy) ────────────────────────
  Stream<List<LeaveRequest>> getAllPendingLeaves() {
    return _firestore
        .collection('leave_requests')
        .where('status', isEqualTo: 'Pending')
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => LeaveRequest.fromDoc(doc)).toList());
  }

  // ─── ADMIN: Get All Leaves ─────────────────────────────────────────
  Stream<List<LeaveRequest>> getAllLeaves() {
    return _firestore
        .collection('leave_requests')
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => LeaveRequest.fromDoc(doc)).toList());
  }

  // ─── ADMIN: Update Leave Status ────────────────────────────────────
  Future<void> updateLeaveStatus(String id, String newStatus) async {
    await _firestore.collection('leave_requests').doc(id).update({'status': newStatus});
  }
}
