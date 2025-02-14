class SessionInfo {
  final String userId;
  final String session;
  final String expire;
  final String sessionId;

  SessionInfo({
    required this.userId,
    required this.session,
    required this.expire,
    required this.sessionId,
  });

  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    return SessionInfo(
      userId: json['userId'],
      session: json['session'],
      expire: json['expire'],
      sessionId: json['sessionId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'session': session,
      'expire': expire,
      'sessionId':sessionId,
    };
  }
}