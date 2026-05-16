import 'package:amazon_cognito_identity_dart_2/cognito.dart';

class CognitoAuthService {
  static const String _userPoolId = 'eu-north-1_JE5LQYoKc';
  static const String _clientId = '1it2qn24uchtnoehg6ee8paqtf';

  static final CognitoUserPool userPool =
      CognitoUserPool(_userPoolId, _clientId);

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
}
