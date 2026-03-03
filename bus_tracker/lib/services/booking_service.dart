import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class BookingService {
  final _database = FirebaseDatabase.instance.ref();

  /// Saves a new bus booking to Firebase Realtime Database
  Future<void> createBooking({
    required String route,
    required String busId,
    required String busNo,
    required String time,
    required DateTime travelDate,
    required int windowSeats,
    required int normalSeats,
    required String passengerName,
    required String passengerPhone,
  }) async {
    try {
      // Create a unique key for the booking
      final newBookingRef = _database.child('bookings').push();
      
      await newBookingRef.set({
        'route': route,
        'busId': busId,
        'busNo': busNo,
        'time': time,
        'travelDate': travelDate.toIso8601String(),
        'windowSeats': windowSeats,
        'normalSeats': normalSeats,
        'totalSeats': windowSeats + normalSeats,
        'passengerName': passengerName,
        'passengerPhone': passengerPhone,
        'timestamp': ServerValue.timestamp,
        'status': 'pending', // pending, confirmed, cancelled
      });
      
      print('Booking created successfully: ${newBookingRef.key}');
    } catch (e) {
      print('Error creating booking: $e');
      rethrow;
    }
  }

  /// Optional: Get bookings for a specific phone number
  Stream<DatabaseEvent> getBookingsByPhone(String phoneNumber) {
    return _database
        .child('bookings')
        .orderByChild('passengerPhone')
        .equalTo(phoneNumber)
        .onValue;
  }
}
