class TerminalConfiguration {
  String credential;
  int transactionId;
  TerminalConfiguration(
      {required this.credential, required this.transactionId});

  factory TerminalConfiguration.fromJson(Map<String, dynamic> json) {
    return TerminalConfiguration(
        credential: json['createTransactionAndGetTerminalCredentials']
                ['terminalCredential'] ??
            json['createTransactionAndGetTerminalCredentials']
                ['terminalCredential'],
        transactionId: json['createTransactionAndGetTerminalCredentials']
                ['transactionId'] ??
            json['createTransactionAndGetTerminalCredentials']
                ['transactionId']);
  }
}
