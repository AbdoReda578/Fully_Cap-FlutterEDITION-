class EmailStatusModel {
  EmailStatusModel({
    required this.configured,
    required this.provider,
    required this.smtpServer,
    required this.emailAddress,
    required this.oauthEnabled,
  });

  final bool configured;
  final String provider;
  final String smtpServer;
  final String emailAddress;
  final bool oauthEnabled;

  factory EmailStatusModel.fromJson(Map<String, dynamic> json) {
    return EmailStatusModel(
      configured: json['configured'] == true,
      provider: (json['provider'] ?? 'Unknown').toString(),
      smtpServer: (json['smtp_server'] ?? '').toString(),
      emailAddress: (json['email_address'] ?? '').toString(),
      oauthEnabled: json['oauth_enabled'] == true,
    );
  }
}
