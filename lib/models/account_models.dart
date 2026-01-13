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

  Map<String, Object?> toStorageJson() {
    return {
      'server': server,
      'port': port,
      'username': username,
      'useTls': useTls,
    };
  }

  ImapAccountConfig copyWith({
    String? password,
  }) {
    return ImapAccountConfig(
      server: server,
      port: port,
      username: username,
      password: password ?? this.password,
      useTls: useTls,
    );
  }

  static ImapAccountConfig fromStorageJson(
    Map<String, Object?> json, {
    required String password,
  }) {
    return ImapAccountConfig(
      server: json['server'] as String? ?? '',
      port: (json['port'] as num?)?.toInt() ?? 993,
      username: json['username'] as String? ?? '',
      password: password,
      useTls: json['useTls'] as bool? ?? true,
    );
  }
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

  Map<String, Object?> toStorageJson() {
    return {
      'id': id,
      'displayName': displayName,
      'email': email,
      'providerType': providerType.name,
      'imapConfig': imapConfig?.toStorageJson(),
    };
  }

  static EmailAccount fromStorageJson(
    Map<String, Object?> json, {
    ImapAccountConfig? imapConfig,
  }) {
    return EmailAccount(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      providerType: EmailProviderType.values.firstWhere(
        (type) => type.name == json['providerType'],
        orElse: () => EmailProviderType.mock,
      ),
      imapConfig: imapConfig,
    );
  }
}
