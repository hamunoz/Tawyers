/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

class PluginModel {
  PluginModel({
    required this.id,
    required this.name,
    required this.version,
    required this.type,
    required this.description,
    this.enabled = true,
    this.isLocal = true,
    this.sourceCode = '',
    this.sourceUrl,
  });

  factory PluginModel.fromMap(Map<String, dynamic> map, {bool isLocal = true, String code = ''}) {
    return PluginModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Plugin sin nombre',
      version: map['version']?.toString() ?? '1.0.0',
      type: map['type']?.toString() ?? 'generic',
      description: map['description']?.toString() ?? '',
      enabled: map['enabled'] as bool? ?? true,
      isLocal: isLocal,
      sourceCode: code,
      sourceUrl: map['sourceUrl']?.toString(),
    );
  }

  final String id;
  final String name;
  final String version;
  final String type;
  final String description;
  bool enabled;
  final bool isLocal;
  String sourceCode;
  final String? sourceUrl;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'version': version,
      'type': type,
      'description': description,
      'enabled': enabled,
      'isLocal': isLocal,
      'sourceUrl': sourceUrl,
    };
  }

  PluginModel copyWith({bool? enabled, String? sourceCode}) {
    return PluginModel(
      id: id,
      name: name,
      version: version,
      type: type,
      description: description,
      enabled: enabled ?? this.enabled,
      isLocal: isLocal,
      sourceCode: sourceCode ?? this.sourceCode,
      sourceUrl: sourceUrl,
    );
  }
}
