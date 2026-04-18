import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ LPU Phagwara Campus Location
  final double allowedLat = 31.2536;
  final double allowedLon = 75.7036;
  final double maxAllowedDistanceInMeters = 300; // 300m covers the full campus

  // Allowed Network (Mobile - set your college WiFi name & BSSID here)
  final String allowedWifiName = "LPU_WiFi";
  final String allowedWifiBSSID = "00:00:00:00:00:00"; // Update with campus BSSID

  // Web Demo Network (not used in web mode anymore)
  final String webDemoWifiName = "Demo WiFi";
  final String webDemoWifiBSSID = "00:00:00:00:00:00";

  Future<String> markAttendance(String uid, String email) async {
    try {
      // 1. Check Location Permission
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return "Location services are disabled. Please enable them.";
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return "Location permissions are denied.";
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        return "Location permissions are permanently denied.";
      }

      // 2. Get Coordinates
      Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));

      if (position.isMocked) {
        return "Fake GPS detected! Attendance rejected.";
      }

      // 3. Get Network Info
      final info = NetworkInfo();
      String wifiName = "Unknown WiFi";
      String wifiBSSID = "Unknown BSSID";

      if (kIsWeb) {
        // Mock values for web debugging
        wifiName = webDemoWifiName;
        wifiBSSID = webDemoWifiBSSID;
      } else {
        try {
          String? name = await info.getWifiName();
          if (name != null) wifiName = name.replaceAll('"', '');
          String? bssid = await info.getWifiBSSID();
          if (bssid != null) wifiBSSID = bssid;
        } catch (e) {
          return "Failed to access WiFi info: $e";
        }
      }

      // 4. Calculate Distance
      double distance = Geolocator.distanceBetween(
        allowedLat,
        allowedLon,
        position.latitude,
        position.longitude,
      );

      // 5. Validation Logic (Universal Testing Mode for Demo)
      bool isApproved = false;
      String locationAlert = "";

      if (kIsWeb) {
        // Web: Automatically approve for testing, but calculate distance for realism
        isApproved = true; 
        if (distance > maxAllowedDistanceInMeters) {
          locationAlert = "(Simulated: You are ${distance.toStringAsFixed(0)}m from campus)";
        }
      } else {
        // Mobile: Check distance and WiFi for real production logic
        isApproved = distance <= maxAllowedDistanceInMeters &&
            wifiName == allowedWifiName &&
            wifiBSSID == allowedWifiBSSID;
        
        // Bypass for demo user
        if (email == "test@lpu.edu.in") isApproved = true;
      }

      if (!isApproved) {
        return "Attendance Rejected:\nYou are ${distance.toStringAsFixed(0)}m away from LPU Campus.\nMust be within ${maxAllowedDistanceInMeters.toStringAsFixed(0)}m of campus.${kIsWeb ? '' : '\nWiFi: $wifiName'}";
      }

      // 6. Save to Firebase
      await _firestore.collection("attendance").add({
        "uid": uid,
        "email": email,
        "latitude": position.latitude,
        "longitude": position.longitude,
        "wifiName": wifiName,
        "wifiBSSID": wifiBSSID,
        "time": FieldValue.serverTimestamp(),
        "status": "Present",
        "isSimulated": locationAlert.isNotEmpty,
      });

      return "SUCCESS: Attendance marked successfully! $locationAlert";
    } catch (e) {
      return "Error: $e";
    }
  }

  // Get stream of previous attendances for specific user
  Stream<QuerySnapshot> getUserAttendance(String uid) {
    return _firestore
        .collection("attendance")
        .where("uid", isEqualTo: uid)
        .orderBy("time", descending: true)
        .snapshots();
  }
}
