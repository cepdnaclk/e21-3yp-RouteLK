import 'dart:convert';
import 'package:http/http.dart' as http;

const String _baseUrl = 'https://g9h4ogzg53.execute-api.eu-north-1.amazonaws.com/prod';

// ─────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────

class BusOption {
  final String busId;
  final String busNumber;
  final String busType;
  final int scheduleId;
  final String departureTime;
  final String arrivalTime;
  final String daysOfWeek;
  final int availableWindowSeats;
  final int availableNormalSeats;

  BusOption({
    required this.busId,
    required this.busNumber,
    required this.busType,
    required this.scheduleId,
    required this.departureTime,
    required this.arrivalTime,
    required this.daysOfWeek,
    required this.availableWindowSeats,
    required this.availableNormalSeats,
  });

  factory BusOption.fromJson(Map<String, dynamic> json) => BusOption(
        busId: json['bus_id'],
        busNumber: json['bus_number'],
        busType: json['bus_type'] ?? 'AC',
        scheduleId: json['schedule_id'],
        departureTime: json['departure_time'] ?? '',
        arrivalTime: json['arrival_time'] ?? '',
        daysOfWeek: json['days_of_week'] ?? '',
        availableWindowSeats: json['available_window_seats'] ?? 0,
        availableNormalSeats: json['available_normal_seats'] ?? 0,
      );
}

class BookingResult {
  final int bookingId;
  final int passengerId;
  final String status;
  final String paymentRef;
  final int totalSeats;

  BookingResult({
    required this.bookingId,
    required this.passengerId,
    required this.status,
    required this.paymentRef,
    required this.totalSeats,
  });

  factory BookingResult.fromJson(Map<String, dynamic> json) => BookingResult(
        bookingId: json['booking_id'],
        passengerId: json['passenger_id'],
        status: json['status'],
        paymentRef: json['payment_ref'] ?? '',
        totalSeats: json['total_seats'] ?? 0,
      );
}

class MyBooking {
  final int bookingId;
  final String passengerName;
  final String contactNo;
  final String travelDate;
  final int noOfSeats;
  final int windowSeats;
  final int normalSeats;
  final String bookingStatus;
  final String paymentStatus;
  final String bookedAt;
  final String busNumber;
  final String busType;
  final String route;

  MyBooking({
    required this.bookingId,
    required this.passengerName,
    required this.contactNo,
    required this.travelDate,
    required this.noOfSeats,
    required this.windowSeats,
    required this.normalSeats,
    required this.bookingStatus,
    required this.paymentStatus,
    required this.bookedAt,
    required this.busNumber,
    required this.busType,
    required this.route,
  });

  factory MyBooking.fromJson(Map<String, dynamic> json) => MyBooking(
        bookingId: json['booking_id'],
        passengerName: json['passenger_name'] ?? '',
        contactNo: json['contact_no'] ?? '',
        travelDate: json['travel_date'] ?? '',
        noOfSeats: json['no_of_seats'] ?? 0,
        windowSeats: json['window_seats'] ?? 0,
        normalSeats: json['normal_seats'] ?? 0,
        bookingStatus: json['booking_status'] ?? 'confirmed',
        paymentStatus: json['payment_status'] ?? 'paid',
        bookedAt: json['booked_at'] ?? '',
        busNumber: json['bus_number'] ?? '',
        busType: json['bus_type'] ?? 'AC',
        route: json['route'] ?? '',
      );
}

// ─────────────────────────────────────────────
// BookingService
// ─────────────────────────────────────────────

class BookingService {
  static final BookingService _instance = BookingService._internal();
  factory BookingService() => _instance;
  BookingService._internal();

  final _client = http.Client();

  // ── Get passenger_id by email ───────────────────────────────────────────
  Future<Map<String, dynamic>> getPassengerByEmail(String email) async {
    final uri = Uri.parse('$_baseUrl/passenger').replace(
      queryParameters: {'email': email.trim().toLowerCase()},
    );
    final response = await _client.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Passenger not found');
    }
  }

  // ── Fetch available buses ────────────────────────────────────────────────
  Future<List<BusOption>> getAvailableBuses({
    required String route,
    required DateTime travelDate,
  }) async {
    final dateStr =
        '${travelDate.year}-${travelDate.month.toString().padLeft(2, '0')}-${travelDate.day.toString().padLeft(2, '0')}';

    final uri = Uri.parse('$_baseUrl/buses').replace(
      queryParameters: {'route': route, 'travel_date': dateStr},
    );
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List busList = data['buses'] ?? [];
      return busList.map((b) => BusOption.fromJson(b)).toList();
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Failed to fetch buses');
    }
  }

  // ── Create booking ───────────────────────────────────────────────────────
  // passengerId MUST be the logged-in user's passenger_id from passengers table
  Future<BookingResult> createBooking({
    required int passengerId,       // ← account's passenger_id
    required String route,
    required String busId,
    required int scheduleId,
    required DateTime travelDate,
    required int windowSeats,
    required int normalSeats,
    required String passengerName,
    required String contactNo,
    String gender = '',
    String paymentRef = 'MOCK_PAYMENT',
  }) async {
    final dateStr =
        '${travelDate.year}-${travelDate.month.toString().padLeft(2, '0')}-${travelDate.day.toString().padLeft(2, '0')}';

    final uri = Uri.parse('$_baseUrl/bookings');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'passenger_id':   passengerId,   // ← send account ID
        'passenger_name': passengerName,
        'contact_no':     contactNo,
        'bus_id':         busId,
        'schedule_id':    scheduleId,
        'travel_date':    dateStr,
        'window_seats':   windowSeats,
        'normal_seats':   normalSeats,
        'gender':         gender,
        'payment_ref':    paymentRef,
      }),
    );

    if (response.statusCode == 201) {
      return BookingResult.fromJson(jsonDecode(response.body));
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Booking failed');
    }
  }

  // ── Cancel a booking ────────────────────────────────────────────────────
  Future<void> cancelBooking({
    required int bookingId,
    required int passengerId,
  }) async {
    final uri = Uri.parse('$_baseUrl/bookings/cancel');
    final response = await _client.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'booking_id':   bookingId,
        'passenger_id': passengerId,
      }),
    );

    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Cancellation failed');
    }
  }

  // ── Get my bookings by passenger_id ─────────────────────────────────────
  Future<List<MyBooking>> getMyBookings({required int passengerId}) async {
    final uri = Uri.parse('$_baseUrl/bookings').replace(
      queryParameters: {'passenger_id': passengerId.toString()},
    );
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List list = data['bookings'] ?? [];
      return list.map((b) => MyBooking.fromJson(b)).toList();
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Failed to fetch bookings');
    }
  }
}