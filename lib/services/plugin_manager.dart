/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:musify/models/plugin_model.dart';
import 'package:musify/services/logger_service.dart';
import 'package:musify/services/plugin_engine.dart';

final PluginManager pluginManager = PluginManager();

class PluginManager {
  factory PluginManager() => _instance;
  PluginManager._internal();
  static final PluginManager _instance = PluginManager._internal();

  final PluginEngine _engine = PluginEngine();
  final Logger _logger = Logger();
  final ValueNotifier<List<PluginModel>> pluginsNotifier = ValueNotifier([]);
  Box? _pluginBox;
  bool _initialized = false;

  final List<String> _assetPlugins = [
    'assets/plugins/iheartradio.js',
    'assets/plugins/radio_browser.js',
    'assets/plugins/iptv_audio.js',
    'assets/plugins/tunein.js',
  ];

  Future<void> init() async {
    if (_initialized) return;
    try {
      _pluginBox = await Hive.openBox('plugin_settings');
      final loadedPlugins = <PluginModel>[];

      for (final assetPath in _assetPlugins) {
        try {
          final jsCode = await rootBundle.loadString(assetPath);
          final plugin = await _engine.loadPluginFromSource(jsCode);
          if (plugin != null) {
            final savedState = _pluginBox?.get('enabled_${plugin.id}', defaultValue: true) as bool? ?? true;
            plugin.enabled = savedState;
            loadedPlugins.add(plugin);
          }
        } catch (e) {
          _logger.log('No se pudo cargar asset plugin: $assetPath', error: e);
        }
      }

      pluginsNotifier.value = loadedPlugins;
      _initialized = true;
    } catch (e, stack) {
      _logger.log('Error al inicializar PluginManager', error: e, stackTrace: stack);
    }
  }

  Future<void> togglePlugin(String pluginId, bool enabled) async {
    await init();
    final list = List<PluginModel>.from(pluginsNotifier.value);
    final index = list.indexWhere((p) => p.id == pluginId);
    if (index != -1) {
      list[index].enabled = enabled;
      await _pluginBox?.put('enabled_$pluginId', enabled);
      pluginsNotifier.value = list;
    }
  }

  Future<List<Map<String, dynamic>>> searchAllPlugins(String query, {List<String>? pluginIds}) async {
    await init();
    final activePlugins = pluginsNotifier.value.where((p) {
      final isEnabled = p.enabled;
      if (!isEnabled) return false;
      if (pluginIds != null && pluginIds.isNotEmpty) {
        return pluginIds.contains(p.id);
      }
      return true;
    }).toList();
    final results = <Map<String, dynamic>>[];

    for (final plugin in activePlugins) {
      try {
        final pluginResults = await _engine.executeSearch(plugin, query);
        results.addAll(pluginResults);
      } catch (e) {
        _logger.log('Error buscando en plugin ${plugin.id}', error: e);
      }
    }

    return results;
  }

  Future<List<Map<String, dynamic>>> getRadioStationsFromPlugins() async {
    await init();
    final activeRadioPlugins = pluginsNotifier.value
        .where((p) => p.enabled && (p.type == 'radio' || p.type == 'generic'))
        .toList();
    final stations = <Map<String, dynamic>>[];

    for (final plugin in activeRadioPlugins) {
      try {
        final list = await _engine.executeGetRadioStations(plugin);
        stations.addAll(list);
      } catch (e) {
        _logger.log('Error obteniendo radios de ${plugin.id}', error: e);
      }
    }

    return stations;
  }

  Future<void> setCustomIptvUrl(String url) async {
    try {
      final box = await Hive.openBox('settings');
      await box.put('iptv_custom_m3u_url', url.trim());
    } catch (e) {
      _logger.log('Error guardando URL M3U personalizada', error: e);
    }
  }

  Future<String> getCustomIptvUrl() async {
    try {
      final box = await Hive.openBox('settings');
      return box.get('iptv_custom_m3u_url', defaultValue: '') as String;
    } catch (_) {
      return '';
    }
  }

  Future<List<Map<String, dynamic>>> getRadioStationsFromPlugin(String pluginId) async {
    await init();
    final activePlugins = pluginsNotifier.value
        .where((p) => p.enabled && p.id == pluginId)
        .toList();
    if (activePlugins.isEmpty) return [];

    try {
      return await _engine.executeGetRadioStations(activePlugins.first);
    } catch (e) {
      _logger.log('Error obteniendo radios de $pluginId', error: e);
      return [];
    }
  }

  Future<Map<String, dynamic>> getStreamUrlForStation(String stationId, String rawUrl) async {
    await init();
    var targetUrl = rawUrl.replaceAll(RegExp('^(tunein|iheartradio|iptv_audio|radio_browser|rb|iheart|iptv):'), '');

    // Si es iHeartRadio y el targetUrl es un ID numérico o no empieza por http, construimos la URL de la API liveStations
    if ((stationId.startsWith('iheart') || rawUrl.contains('iheart')) && !targetUrl.startsWith('http')) {
      targetUrl = 'https://api.iheart.com/api/v2/content/liveStations/$targetUrl';
    }

    if (targetUrl.contains('liveStations/') || targetUrl.contains('Tune.ashx') || targetUrl.contains('.pls') || targetUrl.contains('.m3u')) {
      try {
        debugPrint('🔌 [PLUGIN_STREAM_RESOLVE] Resolviendo URL intermedia nativamente: $targetUrl');
        final response = await http.get(
          Uri.parse(targetUrl),
          headers: {'User-Agent': 'okhttp/4.12.0'},
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (response.body.startsWith('{')) {
            final Map<String, dynamic> data = jsonDecode(response.body);
            final hits = data['hits'] as List?;
            if (hits != null && hits.isNotEmpty) {
              final streams = hits.first['streams'] as Map?;
              if (streams != null) {
                final streamUrl = streams['secure_hls_stream']?.toString() ??
                    streams['secure_shoutcast_stream']?.toString() ??
                    streams['hls_stream']?.toString() ??
                    streams['shoutcast_stream']?.toString();
                if (streamUrl != null && streamUrl.isNotEmpty) {
                  debugPrint('🔌 [PLUGIN_STREAM_RESOLVED] Extraído de iHeart JSON: $streamUrl');
                  return {'url': streamUrl, 'headers': {'User-Agent': 'okhttp/4.12.0'}};
                }
              }
            }
          }

          final lines = response.body.split('\n');
          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.startsWith('File1=')) {
              final parsed = trimmed.substring(6).trim();
              debugPrint('🔌 [PLUGIN_STREAM_RESOLVED] Extraído de PLS: $parsed');
              return {'url': parsed, 'headers': {'User-Agent': 'okhttp/4.12.0'}};
            } else if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
              debugPrint('🔌 [PLUGIN_STREAM_RESOLVED] Extraído de Tune.ashx/M3U: $trimmed');
              return {'url': trimmed, 'headers': {'User-Agent': 'okhttp/4.12.0'}};
            }
          }
        }
      } catch (e) {
        _logger.log('Error resolviendo URL intermedia nativa', error: e);
      }
    }

    final activePlugins = pluginsNotifier.value.where((p) => p.enabled).toList();
    for (final plugin in activePlugins) {
      if (stationId.startsWith('${plugin.id}:')) {
        try {
          final res = await _engine.executeGetStreamUrl(plugin, rawUrl);
          if (res.isNotEmpty && res['url'] != null && res['url'].toString().isNotEmpty) {
            return res;
          }
        } catch (e) {
          _logger.log('Error resolviendo stream para ${plugin.id}', error: e);
        }
      }
    }

    return {'url': targetUrl, 'headers': {'User-Agent': 'okhttp/4.12.0'}};
  }
}
