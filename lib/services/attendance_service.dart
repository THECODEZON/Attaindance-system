import 'package:network_info_plus/network_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/attendance_record.dart';
import '../models/timetable.dart';
import 'geofencing_service.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GeofencingService _geofencingService = GeofencingService();

  // ─── Campus Configuration ───────────────────────────────────────────
  final double allowedLat = GeofencingService.campusLat;
  final double allowedLon = GeofencingService.campusLon;
  final double maxAllowedDistanceInMeters = GeofencingService.campusRadiusMeters;

  final String allowedWifiName = "LPU_WiFi";
  final String allowedWifiBSSID = "00:00:00:00:00:00";

  final String webDemoWifiName = "LPU_WiFi (Simulated)";
  final String webDemoWifiBSSID = "SIM:SIM:SIM:00:00:00";

  // ─── Mark Attendance for a Specific Subject/Class ──────────────────
  Future<Map<String, dynamic>> markAttendance(
    String uid,
    String email,
    ClassSlot classSlot,
  ) async {
    try {
      // 0. Check if already marked for THIS subject TODAY
      final alreadyMarked = await _hasMarkedSubjectToday(uid, classSlot.subjectCode);
      if (alreadyMarked) {
        return {
          'success': false,
          'message': 'Already marked for ${classSlot.subjectName} today.',
          'alreadyMarked': true,
        };
      }

      // ─── Unified Flow (Mobile + Web) ──────────────────────────────

      // 0.5 Check Schedule Time
      bool isTimeValid = classSlot.isActive(DateTime.now());
      if (!isTimeValid) {
        await _saveRecord(
          uid: uid, email: email, classSlot: classSlot,
          lat: allowedLat, lon: allowedLon,
          distance: 0.0, wifi: "N/A", bssid: "N/A",
          status: 'Absent', reason: 'Not within scheduled class time (${classSlot.timeRange}).', simulated: false,
          geofenceStatus: 'N/A',
        );
        return {
          'success': false,
          'message': 'Attendance Rejected:\nNot within scheduled class time (${classSlot.timeRange}). Marked as Absent.',
          'distance': 0.0, 'wifiName': 'N/A',
        };
      }

      // 1. Ensure geofencing service is running
      if (!_geofencingService.isRunning) {
        final started = await _geofencingService.start();
        if (!started) {
          return {'success': false, 'message': 'Location services are disabled or permission denied. Please enable GPS and grant location permission.'};
        }
        // Wait briefly for first location fix
        await Future.delayed(const Duration(seconds: 3));
      }

      // 2. Check geofence status — must be INSIDE campus
      final bool isInRange = _geofencingService.isInsideCampus;
      final double currentLat = _geofencingService.currentLat;
      final double currentLon = _geofencingService.currentLon;
      final String geofenceStatus = _geofencingService.statusNotifier.value.name;

      // 3. Get WiFi info (mobile only — browsers can't access WiFi)
      String wifiName = "N/A (Web)";
      String wifiBSSID = "N/A (Web)";
      bool isOnWifi = true; // Default true on web (skip WiFi check)

      if (!kIsWeb) {
        final info = NetworkInfo();
        try {
          String? name = await info.getWifiName();
          if (name != null) wifiName = name.replaceAll('"', '');
          String? bssid = await info.getWifiBSSID();
          if (bssid != null) wifiBSSID = bssid;
        } catch (e) {
          wifiName = "Unavailable";
          wifiBSSID = "Unavailable";
        }
        isOnWifi = wifiName == allowedWifiName;
      }

      // 4. Validation — Location is ALWAYS required
      bool isApproved = isInRange && isOnWifi;

      String rejectionReason = '';
      if (!isInRange) {
        rejectionReason += 'Geofence: $geofenceStatus — You are outside the LPU Campus (${maxAllowedDistanceInMeters.toStringAsFixed(0)}m zone). ';
      }
      if (!isOnWifi && !kIsWeb) {
        rejectionReason += 'Not connected to "$allowedWifiName" (current: "$wifiName").';
      }

      if (!isApproved) {
        await _saveRecord(
          uid: uid, email: email, classSlot: classSlot,
          lat: currentLat, lon: currentLon,
          distance: 0, wifi: wifiName, bssid: wifiBSSID,
          status: 'Rejected', reason: rejectionReason.trim(), simulated: false,
          geofenceStatus: geofenceStatus,
        );
        return {
          'success': false,
          'message': 'Attendance Rejected:\n$rejectionReason',
          'distance': 0.0, 'wifiName': wifiName,
          'geofenceStatus': geofenceStatus,
        };
      }

      // 5. Approved — Student is inside LPU Campus!
      await _saveRecord(
        uid: uid, email: email, classSlot: classSlot,
        lat: currentLat, lon: currentLon,
        distance: 0, wifi: wifiName, bssid: wifiBSSID,
        status: 'Present', reason: '', simulated: false,
        geofenceStatus: geofenceStatus,
      );

      return {
        'success': true,
        'message': '${classSlot.subjectName} — Attendance marked! ✅\nGeofence: $geofenceStatus',
        'distance': 0.0, 'wifiName': wifiName,
        'geofenceStatus': geofenceStatus,
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ─── Firestore Write ───────────────────────────────────────────────
  Future<void> _saveRecord({
    required String uid,
    required String email,
    required ClassSlot classSlot,
    required double lat,
    required double lon,
    required double distance,
    required String wifi,
    required String bssid,
    required String status,
    required String reason,
    required bool simulated,
    required String geofenceStatus,
  }) async {
    final record = AttendanceRecord(
      uid: uid,
      email: email,
      subjectCode: classSlot.subjectCode,
      subjectName: classSlot.subjectName,
      slotTime: classSlot.timeRange,
      latitude: lat,
      longitude: lon,
      distanceFromCampus: distance,
      wifiName: wifi,
      wifiBSSID: bssid,
      status: status,
      rejectionReason: reason,
      isSimulated: simulated,
    );
    final recordMap = record.toMap();
    recordMap['geofenceStatus'] = geofenceStatus; // Add geofence status to record
    await _firestore.collection('attendance').add(recordMap);
  }

  // ─── Has Already Marked This Subject Today ─────────────────────────
  Future<bool> _hasMarkedSubjectToday(String uid, String subjectCode) async {
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final query = await _firestore
        .collection('attendance')
        .where('uid', isEqualTo: uid)
        .get();

    return query.docs.any((doc) {
      final data = doc.data();
      return data['dateKey'] == todayKey &&
             data['subjectCode'] == subjectCode &&
             data['status'] == 'Present';
    });
  }

  // ─── Get Today's Marked Subjects (returns set of subject codes) ────
  Future<Set<String>> getTodayMarkedSubjects(String uid) async {
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final query = await _firestore
        .collection('attendance')
        .where('uid', isEqualTo: uid)
        .get();

    final markedCodes = <String>{};
    for (var doc in query.docs) {
      final data = doc.data();
      if (data['dateKey'] == todayKey && data['status'] == 'Present') {
        markedCodes.add(data['subjectCode'] ?? '');
      }
    }
    return markedCodes;
  }

  // ─── Attendance History Stream (all records for a user) ────────────
  Stream<List<AttendanceRecord>> getUserAttendanceRecords(String uid) {
    return _firestore
        .collection('attendance')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final records = snapshot.docs
          .map((doc) => AttendanceRecord.fromDoc(doc))
          .toList();
      records.sort((a, b) {
        final aTime = a.markedAt ?? DateTime(2000);
        final bTime = b.markedAt ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });
      return records;
    });
  }

  // ─── Per-Subject Attendance Stats ──────────────────────────────────
  Future<Map<String, Map<String, int>>> getSubjectStats(String uid) async {
    final query = await _firestore
        .collection('attendance')
        .where('uid', isEqualTo: uid)
        .get();

    // Map: subjectCode -> { 'present': N, 'rejected': N, 'absent': N }
    final stats = <String, Map<String, int>>{};

    for (var doc in query.docs) {
      final data = doc.data();
      final code = data['subjectCode'] ?? '';
      if (code.isEmpty) continue;

      stats.putIfAbsent(code, () => {'present': 0, 'rejected': 0, 'absent': 0});
      if (data['status'] == 'Present') {
        stats[code]!['present'] = (stats[code]!['present'] ?? 0) + 1;
      } else if (data['status'] == 'Rejected') {
        stats[code]!['rejected'] = (stats[code]!['rejected'] ?? 0) + 1;
      } else if (data['status'] == 'Absent') {
        stats[code]!['absent'] = (stats[code]!['absent'] ?? 0) + 1;
      }
    }

    return stats;
  }

  // ─── Total Attendance Stats ────────────────────────────────────────
  Future<Map<String, int>> getAttendanceStats(String uid) async {
    final query = await _firestore
        .collection('attendance')
        .where('uid', isEqualTo: uid)
        .get();

    int presentCount = 0;
    int rejectedCount = 0;
    int absentCount = 0;

    for (var doc in query.docs) {
      final data = doc.data();
      if (data['status'] == 'Present') presentCount++;
      else if (data['status'] == 'Rejected') rejectedCount++;
      else if (data['status'] == 'Absent') absentCount++;
    }

    return {
      'present': presentCount,
      'rejected': rejectedCount,
      'absent': absentCount,
      'total': presentCount + rejectedCount + absentCount,
    };
  }
}
