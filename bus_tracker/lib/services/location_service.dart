import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Service to handle location-related functionality
class LocationService {
  /// Default location (Kandy, Sri Lanka)
  static final LatLng defaultLocation = LatLng(7.2906, 80.6337);

  /// Ensures location services and permissions are available.
  static Future<bool> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services are disabled');
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Location permissions are denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('Location permissions are permanently denied');
      return false;
    }

    return true;
  }

  /// Determine the current user position
  /// Returns user's current location or default location if unavailable
  static Future<LatLng> determinePosition() async {
    if (!await _ensurePermission()) {
      return defaultLocation;
    }

    // Get current position
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      print('Error getting location: $e');
      return defaultLocation;
    }
  }

  /// Stream user location updates in real time.
  static Stream<LatLng> positionStream() async* {
    final isReady = await _ensurePermission();
    if (!isReady) {
      yield defaultLocation;
      return;
    }

    yield await determinePosition();

    final stream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );

    yield* stream.map((position) => LatLng(position.latitude, position.longitude));
  }
}
