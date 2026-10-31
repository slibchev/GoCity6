class PassengerSession {
  final String passengerId;
  final String username;
  final String accessToken;
  final String tokenType;
  final int? expiresInSeconds;

  const PassengerSession({
    required this.passengerId,
    required this.username,
    required this.accessToken,
    this.tokenType = 'Bearer',
    this.expiresInSeconds,
  });

  String get authorizationHeader => '$tokenType $accessToken';
}
