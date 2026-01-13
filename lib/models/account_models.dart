import 'package:flutter/material.dart';

enum EmailProviderType {
  mock,
  imap,
}

@immutable
class ImapAccountConfig {
  const ImapAccountConfig({
    required this.server,
    required this.port,
    required this.username,
    required this.password,
    required this.useTls,
  });

  final String server;
  final int port;
  final String username;
  final String password;
  final bool useTls;
}

@immutable
class EmailAccount {
  const EmailAccount({
    required this.id,
    required this.displayName,
    required this.email,
    required this.providerType,
    this.imapConfig,
  });

  final String id;
  final String displayName;
  final String email;
  final EmailProviderType providerType;
  final ImapAccountConfig? imapConfig;
}
