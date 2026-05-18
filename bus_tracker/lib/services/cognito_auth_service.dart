import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'dart:convert';

class CognitoAuthService {
  static const String passengerUserPoolId = 'eu-north-1_JE5LQYoKc';
  static const String passengerClientId = '1it2qn24uchtnoehg6ee8paqtf';
  static const String driverUserPoolId = 'eu-north-1_M6UM0173t';
  static const String driverClientId = '5nd5h1nmojf8qfn7dbablui8vg';
  static const String busOperatorUserPoolId = 'eu-north-1_pUy3ngXWf';
  static const String busOperatorClientId = 'taq6q8tjtcbd423rnl0pj2m28';

  final CognitoUserPool userPool;

  CognitoAuthService._(this.userPool);

  factory CognitoAuthService.passenger() {
    return CognitoAuthService._(
      CognitoUserPool(passengerUserPoolId, passengerClientId),
    );
  }

  factory CognitoAuthService.driver() {
    return CognitoAuthService._(
      CognitoUserPool(driverUserPoolId, driverClientId),
    );
  }

  factory CognitoAuthService.busOperator() {
    return CognitoAuthService._(
      CognitoUserPool(busOperatorUserPoolId, busOperatorClientId),
    );
  }

  /// Sign up a new user. Returns the sign up result from the Cognito SDK.
  Future<dynamic> signUp(String email, String password, String name) async {
    final userAttributes = [AttributeArg(name: 'given_name', value: name)];
    final data = await userPool.signUp(email, password,
        userAttributes: userAttributes);
    return data;
  }

  /// Confirm a newly signed up user with the confirmation code.
  Future<bool> confirmSignUp(String email, String confirmationCode) async {
    final cognitoUser = CognitoUser(email, userPool);
    final confirmed = await cognitoUser.confirmRegistration(confirmationCode);
    return confirmed;
  }

  /// Sign in existing user and return CognitoUserSession on success.
  Future<CognitoUserSession?> signIn(String email, String password) async {
    final cognitoUser = CognitoUser(email, userPool);
    final authDetails = AuthenticationDetails(username: email, password: password);
    final session = await cognitoUser.authenticateUser(authDetails);
    return session;
  }

  /// Extract the signed-in user's display name from the ID token claims.
  String getDisplayNameFromSession(CognitoUserSession? session, String fallback) {
    if (session == null) {
      return fallback;
    }

    final jwtToken = session.getIdToken().getJwtToken();
    if (jwtToken == null || jwtToken.isEmpty) {
      return fallback;
    }

    final parts = jwtToken.split('.');
    if (parts.length < 2) {
      return fallback;
    }

    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final claims = jsonDecode(payload) as Map<String, dynamic>;
      final givenName = claims['given_name']?.toString().trim();
      if (givenName != null && givenName.isNotEmpty) {
        return givenName;
      }

      final fullName = claims['name']?.toString().trim();
      if (fullName != null && fullName.isNotEmpty) {
        return fullName;
      }
    } catch (_) {
      return fallback;
    }

    return fallback;
  }
}
