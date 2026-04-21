import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import '../models/attendance_record.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Campus Configuration ───────────────────────────────────────────
  // ✅ LPU Phagwara Campus Location (center point)
  final double allowedLat = 31.2536;
  final double allowedLon = 75.7036;
  final double maxAllowedDistanceInMeters = 300; // 300m radius around campus

  // ✅ Allowed WiFi network — update these to your actual campus WiFi
  final String allowedWifiName = "LPU_WiFi";
  final String allowedWifiBSSID = "00:00:00:00:00:00";

  // Web demo values (simulation mode)
  final String webDemoWifiName = "LPU_WiFi (Simulated)";
  final String webDemoWifiBSSID = "SIM:SIM:SIM:00:00:00";

  // ─── Main Entry Point ──────────────────────────────────────────────
  Future<Map<String, dynamic>> markAttendance(String uid, String email) async {
    try {
      // 0. Check if already marked today
      final alreadyMarked = await _hasMarkedToday(uid);
      if (alreadyMarked) {
        return {
          'success': false,
          'message': 'You have already marked attendance today.',
          'alreadyMarked': true,
        };
      }

      // ✅ Web Simulation Mode — skip hardware checks
      if (kIsWeb) {
        return await _markAttendanceWeb(uid, email);
      }

      // ─── Mobile Flow ────────────────────────────────────────────

      // 1. Check location services & permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return {
          'success': false,
          'message': 'Location services are disabled. Please enable GPS.',
        };
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return {
            'success': false,
            'message': 'Location permissions are denied.',
          };
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return {
          'success': false,
          'message': 'Location permissions are permanently denied. Go to Settings to enable.',
        };
      }

      // 2. Get current GPS coordinates
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (position.isMocked) {
        return {
          'success': false,
          'message': 'Fake GPS detected! Attendance rejected.',
        };
      }

      // 3. Calculate distance from campus center
      double distance = Geolocator.distanceBetween(
        allowedLat,
        allowedLon,
        position.latitude,
        position.longitude,
      );

      // 4. Get WiFi info
      final info = NetworkInfo();
      String wifiName = "Unknown WiFi";
      String wifiBSSID = "Unknown BSSID";
      try {
        String? name = await info.getWifiName();
        if (name != null) wifiName = name.replaceAll('"', '');
        String? bssid = await info.getWifiBSSID();
        if (bssid != null) wifiBSSID = bssid;
      } catch (e) {
        // WiFi info unavailable — continue but flag it
        wifiName = "Unavailable";
        wifiBSSID = "Unavailable";
      }

      // 5. ──── VALIDATION LOGIC ────
      bool isInRange = distance <= maxAllowedDistanceInMeters;
      bool isOnWifi = wifiName == allowedWifiName;

      // Both conditions must be true
      bool isApproved = isInRange && isOnWifi;

      // Build rejection reason if not approved
      String rejectionReason = '';
      if (!isInRange) {
        rejectionReason += 'You are ${distance.toStringAsFixed(0)}m away (max ${maxAllowedDistanceInMeters.toStringAsFixed(0)}m). ';
      }
      if (!isOnWifi) {
        rejectionReason += 'Not connected to campus WiFi "$allowedWifiName" (current: "$wifiName").';
      }

      if (!isApproved) {
        // Save rejected attempt for audit trail
        await _saveRecord(
          uid: uid,
          email: email,
          lat: position.latitude,
          lon: position.longitude,
          distance: distance,
          wifi: wifiName,
          bssid: wifiBSSID,
          status: 'Rejected',
          reason: rejectionReason.trim(),
          simulated: false,
        );

        return {
          'success': false,
          'message': 'Attendance Rejected:\n$rejectionReason',
          'distance': distance,
          'wifiName': wifiName,
        };
      }

      // 6. Approved — save as Present
      await _saveRecord(
        uid: uid,
        email: email,
        lat: position.latitude,
        lon: position.longitude,
        distance: distance,
        wifi: wifiName,
        bssid: wifiBSSID,
        status: 'Present',
        reason: '',
        simulated: false,
      );

      return {
        'success': true,
        'message': 'Attendance marked successfully!',
        'distance': distance,
        'wifiName': wifiName,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  // ─── Web Simulation ────────────────────────────────────────────────
  Future<Map<String, dynamic>> _markAttendanceWeb(String uid, String email) async {
    await _saveRecord(
      uid: uid,
      email: email,
      lat: allowedLat,
      lon: allowedLon,
      distance: 0,
      wifi: webDemoWifiName,
      bssid: webDemoWifiBSSID,
      status: 'Present',
      reason: '',
      simulated: true,
    );

    return {
      'success': true,
      'message': 'Attendance marked successfully! (Web Simulation)',
      'distance': 0.0,
      'wifiName': webDemoWifiName,
    };
  }

  // ─── Firestore Write ───────────────────────────────────────────────
  Future<void> _saveRecord({
    required String uid,
    required String email,
    required double lat,
    required double lon,
    required double distance,
    required String wifi,
    required String bssid,
    required String status,
    required String reason,
    required bool simulated,
  }) async {
    final record = AttendanceRecord(
      uid: uid,
      email: email,
      latitude: lat,
      longitude: lon,
      distanceFromCampus: distance,
      wifiName: wifi,
      wifiBSSID: bssid,
      status: status,
      rejectionReason: reason,
      isSimulated: simulated,
    );

    await _firestore.collection('attendance').add(record.toMap());
  }

  // ─── Duplicate Prevention (single-field query, no composite index needed) ──
  Future<bool> _hasMarkedToday(String uid) async {
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Query only by uid, then filter client-side to avoid composite index
    final query = await _firestore
        .collection('attendance')
        .where('uid', isEqualTo: uid)
        .get();

    return query.docs.any((doc) {
      final data = doc.data();
      return data['dateKey'] == todayKey && data['status'] == 'Present';
    });
  }

  // ─── Today's Status Check ──────────────────────────────────────────
  Future<AttendanceRecord?> getTodayRecord(String uid) async {
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Query only by uid, then filter client-side
    final query = await _firestore
        .collection('attendance')
        .where('uid', isEqualTo: uid)
        .get();

    for (var doc in query.docs) {
      final data = doc.data();
      if (data['dateKey'] == todayKey && data['status'] == 'Present') {
        return AttendanceRecord.fromDoc(doc);
      }
    }
    return null;
  }

  // ─── Attendance History Stream (single where, no orderBy = no composite index) ──
  Stream<List<AttendanceRecord>> getUserAttendanceRecords(String uid) {
    return _firestore
        .collection('attendance')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final records = snapshot.docs
          .map((doc) => AttendanceRecord.fromDoc(doc))
          .toList();
      // Sort client-side by markedAt descending
      records.sort((a, b) {
        final aTime = a.markedAt ?? DateTime(2000);
        final bTime = b.markedAt ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });
      return records;
    });
  }

  // ─── Attendance Stats (reuse single-field query) ───────────────────
  Future<Map<String, int>> getAttendanceStats(String uid) async {
    final query = await _firestore
        .collection('attendance')
        .where('uid', isEqualTo: uid)
        .get();

    int presentCount = 0;
    int rejectedCount = 0;

    for (var doc in query.docs) {
      final data = doc.data();
      if (data['status'] == 'Present') {
        presentCount++;
      } else if (data['status'] == 'Rejected') {
        rejectedCount++;
      }
    }

    return {
      'present': presentCount,
      'rejected': rejectedCount,
      'total': presentCount + rejectedCount,
    };
  }
}
