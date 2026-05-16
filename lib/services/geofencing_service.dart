import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geofencing_api/geofencing_api.dart';

/// Service that manages real-time geofence monitoring around LPU Campus.
/// Uses the geofencing_api package for circular geofence with enter/exit/dwell events.
class GeofencingService {
  static final GeofencingService _instance = GeofencingService._internal();
  factory GeofencingService() => _instance;
  GeofencingService._internal();

  // ─── Campus Configuration ───────────────────────────────────────────
  static const double campusLat = 31.255528;
  static const double campusLon = 75.704194;
  static const double campusRadiusMeters = 20000;

  // ─── State ──────────────────────────────────────────────────────────
  final ValueNotifier<GeofenceStatus> statusNotifier =
      ValueNotifier(GeofenceStatus.exit);

  final ValueNotifier<Location?> locationNotifier = ValueNotifier(null);

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// Returns true if the student is currently inside the campus geofence.
  bool get isInsideCampus {
    final status = statusNotifier.value;
    if (status == GeofenceStatus.enter || status == GeofenceStatus.dwell) {
      return true;
    }

    // Fallback: Manual distance calculation if location is known
    if (locationNotifier.value != null) {
      final distance = _calculateDistance(
        locationNotifier.value!.latitude,
        locationNotifier.value!.longitude,
        campusLat,
        campusLon,
      );
      // If manually calculated distance is within radius, treat as inside
      if (distance <= campusRadiusMeters) return true;
    }

    return false;
  }

  /// Calculates the distance between two points in meters using the Haversine formula.
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = (0.5 - 
        (0.5 * (lat2 - lat1).abs().sign * (lat1 + lat2).abs().sign * (lat1 - lat2).abs().sign) / 2) * 
        (1 - (lat2 - lat1).abs().sign);
    // Note: Simple Euclidean approximation for short distances or Haversine for accuracy
    // Using a simpler approach for now to avoid complex math imports if not needed, 
    // but Haversine is better. Let's use a standard implementation.
    
    final double a_haversine = 
        (0.5 - (0.5 * (lat2 - lat1).abs().sign * (lat1 + lat2).abs().sign * (lat1 - lat2).abs().sign) / 2);
    // Actually, let's just use the geofencing_api's LatLng distance if available, 
    // or a standard Haversine.
    
    // Using math import for Haversine
    return _haversineDistance(lat1, lon1, lat2, lon2);
  }

  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0; // Earth radius in meters
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final dPhi = (lat2 - lat1) * math.pi / 180;
    final dLambda = (lon2 - lon1) * math.pi / 180;

    final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
        math.cos(phi1) * math.cos(phi2) *
        math.sin(dLambda / 2) * math.sin(dLambda / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return R * c;
  }

  double _toRadians(double degree) => degree * 3.1415926535897932 / 180;

  /// Returns the last known latitude, or campus center as fallback.
  double get currentLat => locationNotifier.value?.latitude ?? campusLat;

  /// Returns the last known longitude, or campus center as fallback.
  double get currentLon => locationNotifier.value?.longitude ?? campusLon;

  /// Returns the current geofence status as a readable string.
  String get statusText {
    switch (statusNotifier.value) {
      case GeofenceStatus.enter:
        return 'Entered Campus';
      case GeofenceStatus.dwell:
        return 'Inside Campus';
      case GeofenceStatus.exit:
        return 'Outside Campus';
    }
  }

  // ─── Geofence Region ───────────────────────────────────────────────
  final Set<GeofenceRegion> _regions = {
    GeofenceRegion.circular(
      id: 'lpu_campus',
      data: {'name': 'LPU Campus'},
      center: const LatLng(campusLat, campusLon),
      radius: campusRadiusMeters,
      loiteringDelay: 30 * 1000, // 30 seconds before dwell
    ),
  };

  // ─── Permission ────────────────────────────────────────────────────
  Future<bool> requestLocationPermission() async {
    // Web doesn't need native permission flow
    if (kIsWeb) return true;

    if (!await Geofencing.instance.isLocationServicesEnabled) {
      return false;
    }

    LocationPermission permission =
        await Geofencing.instance.getLocationPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geofencing.instance.requestLocationPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  // ─── Setup & Start ─────────────────────────────────────────────────
  Future<bool> start() async {
    if (_isRunning) return true;

    final hasPermission = await requestLocationPermission();
    if (!hasPermission) return false;

    // Configure geofencing
    Geofencing.instance.setup(
      interval: 5000, // Check every 5 seconds
      accuracy: 50, // 50m accuracy for better detection
      statusChangeDelay: 10000, // 10 seconds debounce
      allowsMockLocation: kIsWeb, // Allow on web (browser can't detect mocks), block on mobile
      printsDebugLog: kDebugMode,
    );

    // Add listeners
    Geofencing.instance
        .addGeofenceStatusChangedListener(_onGeofenceStatusChanged);
    Geofencing.instance.addLocationChangedListener(_onLocationChanged);
    Geofencing.instance.addGeofenceErrorCallbackListener(_onGeofenceError);

    // Start monitoring
    await Geofencing.instance.start(regions: _regions);
    _isRunning = true;
    return true;
  }

  // ─── Stop ──────────────────────────────────────────────────────────
  Future<void> stop() async {
    if (!_isRunning) return;

    Geofencing.instance
        .removeGeofenceStatusChangedListener(_onGeofenceStatusChanged);
    Geofencing.instance.removeLocationChangedListener(_onLocationChanged);
    Geofencing.instance.removeGeofenceErrorCallbackListener(_onGeofenceError);

    await Geofencing.instance.stop();
    _isRunning = false;
  }

  // ─── Listeners ─────────────────────────────────────────────────────
  Future<void> _onGeofenceStatusChanged(
    GeofenceRegion region,
    GeofenceStatus status,
    Location location,
  ) async {
    debugPrint(
        '📍 Geofence [${region.id}]: ${status.name} at (${location.latitude}, ${location.longitude})');
    statusNotifier.value = status;
    locationNotifier.value = location;
  }

  void _onLocationChanged(Location location) {
    locationNotifier.value = location;
  }

  void _onGeofenceError(Object error, StackTrace stackTrace) {
    debugPrint('❌ Geofence error: $error\n$stackTrace');
  }

  /// Dispose all resources. Call when app is shutting down.
  Future<void> dispose() async {
    await stop();
    statusNotifier.dispose();
    locationNotifier.dispose();
  }
}
