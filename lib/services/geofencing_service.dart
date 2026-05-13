import 'package:flutter/foundation.dart';
import 'package:geofencing_api/geofencing_api.dart';

/// Service that manages real-time geofence monitoring around LPU Campus.
/// Uses the geofencing_api package for circular geofence with enter/exit/dwell events.
class GeofencingService {
  static final GeofencingService _instance = GeofencingService._internal();
  factory GeofencingService() => _instance;
  GeofencingService._internal();

  // ─── Campus Configuration ───────────────────────────────────────────
  static const double campusLat = 31.2536;
  static const double campusLon = 75.7036;
  static const double campusRadiusMeters = 300;

  // ─── State ──────────────────────────────────────────────────────────
  final ValueNotifier<GeofenceStatus> statusNotifier =
      ValueNotifier(GeofenceStatus.exit);

  final ValueNotifier<Location?> locationNotifier = ValueNotifier(null);

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// Returns true if the student is currently inside the campus geofence.
  bool get isInsideCampus {
    final status = statusNotifier.value;
    return status == GeofenceStatus.enter || status == GeofenceStatus.dwell;
  }

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
