// lib/services/validation_service.dart

class ValidationService {
  /// 3.1 Passenger Login Validation - Email Validation
  static bool validateLoginEmail(String? email) {
    if (email == null) {
      throw ArgumentError('Email cannot be null');
    }
    if (email.trim().isEmpty) {
      throw ArgumentError('Email cannot be empty');
    }
    
    final trimmed = email.trim();
    
    // Check for SQL injection patterns (e.g. ' OR '1'='1)
    final sqlInjectionPatterns = [
      r"'\s*or\s*",
      r"'\s*and\s*",
      r"union\s+select",
      r"select\s+.*\s+from",
      r"insert\s+into",
      r"delete\s+from",
      r"drop\s+table",
    ];
    for (final pattern in sqlInjectionPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(trimmed)) {
        throw ArgumentError('SQL injection strings detected');
      }
    }

    // Email format validation
    final emailRegex = RegExp(
        r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$");
    if (!emailRegex.hasMatch(trimmed)) {
      throw ArgumentError('Invalid email format');
    }

    return true;
  }

  /// 3.1 Passenger Login Validation - Password Validation
  static bool validateLoginPassword(String? password) {
    if (password == null) {
      throw ArgumentError('Password cannot be null');
    }
    if (password.isEmpty) {
      throw ArgumentError('Password cannot be empty');
    }
    if (password.length < 8) {
      throw ArgumentError('Password length = 7 characters (Invalid)');
    }
    if (password.length > 32) {
      throw ArgumentError('Password length = 33 characters (Invalid)');
    }
    return true;
  }

  /// 3.1 Passenger Login - Complete Validation process (mocking Cognito/DB backend)
  static Future<bool> loginPassenger({
    required String? email,
    required String? password,
    required Future<bool> Function(String email) checkEmailRegistered,
    required Future<bool> Function(String email, String password) authenticate,
  }) async {
    validateLoginEmail(email);
    validateLoginPassword(password);

    final normalizedEmail = email!.trim().toLowerCase();

    // Mock/External database call checks
    final isRegistered = await checkEmailRegistered(normalizedEmail);
    if (!isRegistered) {
      throw Exception('Unregistered email');
    }

    final isAuth = await authenticate(normalizedEmail, password!);
    if (!isAuth) {
      throw Exception('Incorrect password');
    }

    return true;
  }

  /// 3.2 Search Bus - Route input validation
  static bool validateRouteSearch(String? route) {
    if (route == null) {
      throw ArgumentError('Null route');
    }
    if (route.trim().isEmpty) {
      throw ArgumentError('Empty route');
    }

    final trimmed = route.trim();

    // Check for special characters
    if (RegExp(r'[^\w\s\-]').hasMatch(trimmed)) {
      throw ArgumentError('Special characters');
    }

    final routeNum = int.tryParse(trimmed);
    if (routeNum == null) {
      throw ArgumentError('Invalid route number');
    }

    if (routeNum < 1 || routeNum > 9999) {
      throw ArgumentError('Route number boundary violation');
    }

    return true;
  }

  /// 3.2 Search Bus - Complete search execution (mocking route retrieval)
  static Future<bool> searchBus({
    required String? route,
    required Future<List<String>> Function() fetchRegisteredRoutes,
  }) async {
    validateRouteSearch(route);

    final trimmedRoute = route!.trim();
    final registeredRoutes = await fetchRegisteredRoutes();

    if (!registeredRoutes.contains(trimmedRoute)) {
      throw Exception('Non-existing route');
    }

    return true;
  }

  /// 3.3 Passenger Count Update
  static int updatePassengerCount({
    required int? currentCount,
    required String? action,
    required int? delta,
    int maxCapacity = 60,
  }) {
    if (currentCount == null || action == null || delta == null) {
      throw ArgumentError('Null input values');
    }
    if (currentCount < 0) {
      throw ArgumentError('Negative passenger count');
    }
    if (currentCount > maxCapacity) {
      throw ArgumentError('Current count exceeds maximum capacity');
    }
    if (delta < 0) {
      throw ArgumentError('Delta cannot be negative');
    }

    final normalizedAction = action.trim().toLowerCase();
    if (normalizedAction != 'enter' && normalizedAction != 'exit') {
      throw ArgumentError('Invalid action value');
    }

    if (normalizedAction == 'enter') {
      if (currentCount + delta > maxCapacity) {
        throw StateError('Passenger enters when the bus is full');
      }
      return currentCount + delta;
    } else {
      if (currentCount - delta < 0) {
        throw StateError('Passenger exits when count is zero');
      }
      return currentCount - delta;
    }
  }

  /// 3.4 Pickup Request Validation
  static bool validatePickupRequest({
    required int? passengerId,
    required String? busId,
    required List<Map<String, dynamic>>? existingQueue,
    int maxQueueSize = 5,
  }) {
    if (passengerId == null || busId == null || existingQueue == null) {
      throw ArgumentError('Null IDs');
    }
    if (busId.trim().isEmpty) {
      throw ArgumentError('Empty IDs');
    }
    if (passengerId <= 0) {
      throw ArgumentError('Invalid passenger');
    }

    // Duplicate submission / pickup check
    for (final request in existingQueue) {
      if (request['passengerId'] == passengerId && request['busId'] == busId) {
        throw StateError('Duplicate pickup request');
      }
    }

    // Boundary / Queue overflow check
    if (existingQueue.length >= maxQueueSize) {
      throw StateError('Queue overflow');
    }

    return true;
  }
}
