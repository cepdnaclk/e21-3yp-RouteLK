import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'dart:convert';
import 'api_service.dart';

class CognitoAuthService {
  static const String passengerUserPoolId = 'eu-north-1_JE5LQYoKc';
  static const String passengerClientId   = '1it2qn24uchtnoehg6ee8paqtf';
  static const String driverUserPoolId    = 'eu-north-1_M6UM0173t';
  static const String driverClientId      = '5nd5h1nmojf8qfn7dbablui8vg';
  static const String busOperatorUserPoolId = 'eu-north-1_pUy3ngXWf';
  static const String busOperatorClientId   = 'taq6q8tjtcbd423rnl0pj2m28';

  final CognitoUserPool userPool;
  final String userPoolId; // kept so deleteAccount knows which table to target

  CognitoAuthService._(this.userPool, this.userPoolId);

  factory CognitoAuthService.passenger() {
    return CognitoAuthService._(
      CognitoUserPool(passengerUserPoolId, passengerClientId),
      passengerUserPoolId,
    );
  }

  factory CognitoAuthService.driver() {
    return CognitoAuthService._(
      CognitoUserPool(driverUserPoolId, driverClientId),
      driverUserPoolId,
    );
  }

  factory CognitoAuthService.busOperator() {
    return CognitoAuthService._(
      CognitoUserPool(busOperatorUserPoolId, busOperatorClientId),
      busOperatorUserPoolId,
    );
  }

  /// Normalize email: trim whitespace and lowercase.
  String _normalizeEmail(String email) => email.trim().toLowerCase();

  /// Sign up a new user.
  Future<dynamic> signUp(String email, String password, String name) async {
    final normalizedEmail = _normalizeEmail(email);
    final userAttributes = [AttributeArg(name: 'given_name', value: name)];
    return await userPool.signUp(
      normalizedEmail,
      password,
      userAttributes: userAttributes,
    );
  }

  /// Confirm a newly signed up user with the confirmation code.
  Future<bool> confirmSignUp(String email, String confirmationCode) async {
    final normalizedEmail = _normalizeEmail(email);
    final cognitoUser = CognitoUser(normalizedEmail, userPool);
    return await cognitoUser.confirmRegistration(confirmationCode);
  }

  /// Sign in existing user and return CognitoUserSession on success.
  Future<CognitoUserSession?> signIn(String email, String password) async {
    final normalizedEmail = _normalizeEmail(email);
    final cognitoUser = CognitoUser(normalizedEmail, userPool);
    final authDetails = AuthenticationDetails(
      username: normalizedEmail,
      password: password,
    );
    return await cognitoUser.authenticateUser(authDetails);
  }

  /// Update the user's display name in Cognito.
  Future<void> updateDisplayName(
      String email, String currentPassword, String newName) async {
    final normalizedEmail = _normalizeEmail(email);
    final cognitoUser = CognitoUser(normalizedEmail, userPool);
    final authDetails = AuthenticationDetails(
      username: normalizedEmail,
      password: currentPassword,
    );
    await cognitoUser.authenticateUser(authDetails);
    await cognitoUser.updateAttributes(
        [CognitoUserAttribute(name: 'given_name', value: newName)]);
  }

  /// Change the signed-in user's password.
  Future<void> changePassword(
      String email, String currentPassword, String newPassword) async {
    final normalizedEmail = _normalizeEmail(email);
    final cognitoUser = CognitoUser(normalizedEmail, userPool);
    final authDetails = AuthenticationDetails(
      username: normalizedEmail,
      password: currentPassword,
    );
    await cognitoUser.authenticateUser(authDetails);
    await cognitoUser.changePassword(currentPassword, newPassword);
  }

  /// Delete the signed-in user's account.
  /// Order: authenticate → delete from DB → delete from Cognito.
  /// If DB delete fails, Cognito user stays intact so the user can retry.
  Future<void> deleteAccount(String email, String currentPassword) async {
    final normalizedEmail = _normalizeEmail(email);
    final cognitoUser = CognitoUser(normalizedEmail, userPool);
    final authDetails = AuthenticationDetails(
      username: normalizedEmail,
      password: currentPassword,
    );

    // Step 1: Authenticate
    await cognitoUser.authenticateUser(authDetails);

    // Step 2: Delete from DB first (passes userPoolId so Lambda picks correct table)
    await ApiService.deleteUserFromDb(normalizedEmail, userPoolId);

    // Step 3: Delete from Cognito only after DB succeeds
    await cognitoUser.deleteUser();
  }

  /// Resend the confirmation code to the user's email.
  Future<void> resendConfirmationCode(String email) async {
    final normalizedEmail = _normalizeEmail(email);
    final cognitoUser = CognitoUser(normalizedEmail, userPool);
    await cognitoUser.resendConfirmationCode();
  }

  /// Extract the signed-in user's display name from the ID token claims.
  String getDisplayNameFromSession(
      CognitoUserSession? session, String fallback) {
    if (session == null) return fallback;

    final jwtToken = session.getIdToken().getJwtToken();
    if (jwtToken == null || jwtToken.isEmpty) return fallback;

    final parts = jwtToken.split('.');
    if (parts.length < 2) return fallback;

    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final claims = jsonDecode(payload) as Map<String, dynamic>;

      final givenName = claims['given_name']?.toString().trim();
      if (givenName != null && givenName.isNotEmpty) return givenName;

      final fullName = claims['name']?.toString().trim();
      if (fullName != null && fullName.isNotEmpty) return fullName;

      final email = claims['email']?.toString().trim();
      if (email != null && email.isNotEmpty) return email;
    } catch (_) {
      return fallback;
    }

    return fallback;
  }

  /// Get user's display name from Cognito attributes.
  Future<String?> getCurrentUserDisplayName(String email) async {
    try {
      final normalizedEmail = _normalizeEmail(email);
      final cognitoUser = CognitoUser(normalizedEmail, userPool);
      final attributes = await cognitoUser.getUserAttributes();
      if (attributes != null) {
        for (var attr in attributes) {
          if (attr.name == 'given_name' && attr.value?.isNotEmpty == true) {
            return attr.value;
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}