import 'dart:io';

import 'package:yaml/yaml.dart';

class TidingsConfigStore {
  static Future<Directory?> configDirectory() async {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'];
    if (home == null || home.isEmpty) {
      return null;
    }
    return Directory('$home/.config/tidings');
  }

  static Future<File?> configFile() async {
    final dir = await configDirectory();
    if (dir == null) {
      return null;
    }
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/config.yml');
  }

  static Future<File?> legacyConfigFile() async {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'];
    if (home == null || home.isEmpty) {
      return null;
    }
    return File('$home/.config/tidings.yml');
  }

  static Future<Map<String, Object?>?> loadConfig() async {
    final file = await configFile();
    final legacyFile = await legacyConfigFile();
    if (file == null) {
      return null;
    }
    if (await file.exists()) {
      if (legacyFile != null && await legacyFile.exists()) {
        try {
          await legacyFile.delete();
        } catch (_) {}
      }
    }
    File? source = file;
    if (!await file.exists()) {
      if (legacyFile != null && await legacyFile.exists()) {
        source = legacyFile;
      } else {
        return null;
      }
    }
    try {
      final raw = await source.readAsString();
      final decoded = loadYaml(raw);
      if (decoded is! YamlMap) {
        return null;
      }
      final mapped = yamlToMap(decoded);
      if (source.path != file.path) {
        await writeConfig(mapped);
        try {
          await source.delete();
        } catch (_) {}
      }
      return mapped;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, Object?>> loadConfigOrEmpty() async {
    return await loadConfig() ?? <String, Object?>{};
  }

  static Future<void> writeConfig(Map<String, Object?> payload) async {
    final file = await configFile();
    if (file == null) {
      return;
    }
    final yaml = toYaml(payload);
    await file.writeAsString(yaml);
  }

  static Map<String, Object?> yamlToMap(YamlMap map) {
    final result = <String, Object?>{};
    for (final entry in map.entries) {
      final key = entry.key;
      if (key is! String) {
        continue;
      }
      result[key] = yamlToValue(entry.value);
    }
    return result;
  }

  static Object? yamlToValue(Object? value) {
    if (value is YamlMap) {
      return yamlToMap(value);
    }
    if (value is YamlList) {
      return value.map(yamlToValue).toList();
    }
    return value;
  }

  static String toYaml(Object? value, {int indent = 0}) {
    final space = ' ' * indent;
    if (value is Map) {
      final buffer = StringBuffer();
      for (final entry in value.entries) {
        final key = entry.key;
        if (key == null) {
          continue;
        }
        final keyText = key.toString();
        final entryValue = entry.value;
        if (entryValue is Map || entryValue is List) {
          buffer.writeln('$space$keyText:');
          buffer.write(toYaml(entryValue, indent: indent + 2));
        } else {
          buffer.writeln('$space$keyText: ${yamlScalar(entryValue)}');
        }
      }
      return buffer.toString();
    }
    if (value is List) {
      final buffer = StringBuffer();
      for (final item in value) {
        if (item is Map || item is List) {
          buffer.writeln('$space-');
          buffer.write(toYaml(item, indent: indent + 2));
        } else {
          buffer.writeln('$space- ${yamlScalar(item)}');
        }
      }
      return buffer.toString();
    }
    return '$space${yamlScalar(value)}\n';
  }

  static String yamlScalar(Object? value) {
    if (value == null) {
      return 'null';
    }
    if (value is bool || value is num) {
      return value.toString();
    }
    final text = value.toString();
    final needsQuotes = text.isEmpty ||
        text.contains(':') ||
        text.contains('#') ||
        text.contains('\n') ||
        text.startsWith(' ') ||
        text.endsWith(' ');
    if (!needsQuotes) {
      return text;
    }
    final escaped = text.replaceAll('"', r'\"');
    return '"$escaped"';
  }
}
