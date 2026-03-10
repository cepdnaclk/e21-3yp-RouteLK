import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Service to handle location-related functionality
class LocationService {
  /// Default location (Kandy, Sri Lanka)
  static final LatLng defaultLocation = LatLng(7.2906, 80.6337);

  /// Determine the current user position
  /// Returns user's current location or default location if unavailable
  static Future<LatLng> determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services are disabled');
      return defaultLocation;
    }

    // Check location permission
    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Location permissions are denied');
        return defaultLocation;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('Location permissions are permanently denied');
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
}
