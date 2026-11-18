class PassengerSession {
  final String passengerId;
  final String? username;
  final String? authMethod;
  final String accessToken;
  final String? refreshToken;
  final String tokenType;
  final int? expiresInSeconds;

  const PassengerSession({
    required this.passengerId,
    required this.username,
    required this.accessToken,
    this.authMethod,
    this.refreshToken,
    this.tokenType = 'Bearer',
    this.expiresInSeconds,
  });

  String get authorizationHeader => '$tokenType $accessToken';
}
