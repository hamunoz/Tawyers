/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:musify/models/plugin_model.dart';
import 'package:musify/services/logger_service.dart';

class PluginEngine {
  late JavascriptRuntime _jsRuntime;
  bool _initialized = false;
  final Logger _logger = Logger();

  Future<void> init() async {
    if (_initialized) return;
    try {
      debugPrint('🔌 [PLUGIN_ENGINE] Inicializando QuickJS Runtime...');
      _jsRuntime = getJavascriptRuntime();
      _initialized = true;
      debugPrint('🔌 [PLUGIN_ENGINE] QuickJS Runtime inicializado con éxito');
    } catch (e, stack) {
      debugPrint('❌ [PLUGIN_ERROR] Error inicializando PluginEngine JS: $e');
      _logger.log('Error inicializando PluginEngine JS', error: e, stackTrace: stack);
    }
  }

  Future<String> _evalJs(String jsCode) async {
    await init();
    try {
      final result = await _jsRuntime.evaluateAsync(jsCode);
      return result.stringResult;
    } catch (e) {
      debugPrint('❌ [PLUGIN_EVAL_ERROR] $e');
      return '';
    }
  }

  Future<PluginModel?> loadPluginFromSource(String jsCode) async {
    await init();
    try {
      final codeToEval = '''
        (function() {
          $jsCode
          if (typeof plugin !== 'undefined') {
            return JSON.stringify({
              id: plugin.id,
              name: plugin.name,
              version: plugin.version,
              type: plugin.type,
              description: plugin.description,
              enabled: plugin.enabled,
              initialUrl: plugin.initialUrl || ''
            });
          }
          return null;
        })();
      ''';

      final resultStr = await _evalJs(codeToEval);
      if (resultStr != 'null' && resultStr.isNotEmpty) {
        final Map<String, dynamic> map = jsonDecode(resultStr);
        final plugin = PluginModel.fromMap(map, code: jsCode);
        debugPrint('🔌 [PLUGIN_LOADED] Plugin cargado: ${plugin.name} (${plugin.id})');
        return plugin;
      }
    } catch (e) {
      debugPrint('❌ [PLUGIN_LOAD_ERROR] Error parseando plugin: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> executeGetRadioStations(PluginModel plugin) async {
    await init();
    try {
      debugPrint('🔌 [PLUGIN_CALL] Solicitando URL inicial de ${plugin.id}...');
      
      final urlCode = '''
        (function() {
          ${plugin.sourceCode}
          if (typeof plugin !== 'undefined' && typeof plugin.getInitialUrl === 'function') {
            return plugin.getInitialUrl();
          }
          return plugin.initialUrl || '';
        })();
      ''';

      var targetUrl = await _evalJs(urlCode);
      if (plugin.id == 'iptv_audio') {
        final box = await Hive.openBox('settings');
        final customUrl = box.get('iptv_custom_m3u_url', defaultValue: '') as String;
        if (customUrl.isNotEmpty) {
          targetUrl = customUrl;
          debugPrint('🔌 [PLUGIN_IPTV] Usando URL personalizada M3U: $targetUrl');
        }
      }

      debugPrint('🔌 [PLUGIN_HTTP] Fetcheando nativamente en Dart -> $targetUrl');

      if (targetUrl.isEmpty || !targetUrl.startsWith('http')) {
        debugPrint('⚠️ [PLUGIN_WARN] ${plugin.id} no definió URL inicial válida');
        return [];
      }

      // Usamos el User-Agent nativo okhttp/4.12.0 igual que OkHttp en Kotlin para evitar HTTP 403 Forbidden
      final response = await http.get(
        Uri.parse(targetUrl),
        headers: {'User-Agent': 'okhttp/4.12.0'},
      ).timeout(const Duration(seconds: 10));

      debugPrint('🔌 [PLUGIN_HTTP_RESP] Status: ${response.statusCode} | Length: ${response.body.length}');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return [];
      }

      final parseCode = '''
        (function() {
          ${plugin.sourceCode}
          if (typeof plugin !== 'undefined' && typeof plugin.parseRadioStations === 'function') {
            var res = plugin.parseRadioStations(${jsonEncode(response.body)});
            return JSON.stringify(res || []);
          }
          return '[]';
        })();
      ''';

      final parsedResultStr = await _evalJs(parseCode);
      final decoded = jsonDecode(parsedResultStr);
      if (decoded is List) {
        debugPrint('🔌 [PLUGIN_RESULT] ${plugin.id} parseó ${decoded.length} emisoras con éxito!');
        return List<Map<String, dynamic>>.from(decoded.map((item) => Map<String, dynamic>.from(item)));
      }
    } catch (e) {
      debugPrint('❌ [PLUGIN_EXEC_ERROR] Error ejecutando getRadioStations en ${plugin.id}: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> executeSearch(PluginModel plugin, String query) async {
    await init();
    try {
      debugPrint('🔌 [PLUGIN_CALL] Buscando en ${plugin.id}: "$query"...');

      final urlCode = '''
        (function() {
          ${plugin.sourceCode}
          if (typeof plugin !== 'undefined' && typeof plugin.getSearchUrl === 'function') {
            return plugin.getSearchUrl("$query");
          }
          return '';
        })();
      ''';

      final searchUrl = await _evalJs(urlCode);
      if (searchUrl.isEmpty || !searchUrl.startsWith('http')) {
        return [];
      }

      debugPrint('🔌 [PLUGIN_HTTP] Buscando URL nativa -> $searchUrl');

      final response = await http.get(
        Uri.parse(searchUrl),
        headers: {'User-Agent': 'okhttp/4.12.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return [];
      }

      final parseCode = '''
        (function() {
          ${plugin.sourceCode}
          if (typeof plugin !== 'undefined' && typeof plugin.parseSearchResults === 'function') {
            var res = plugin.parseSearchResults(${jsonEncode(response.body)}, "$query");
            return JSON.stringify(res || []);
          }
          return '[]';
        })();
      ''';

      final parsedResultStr = await _evalJs(parseCode);
      final decoded = jsonDecode(parsedResultStr);
      if (decoded is List) {
        debugPrint('🔌 [PLUGIN_RESULT] ${plugin.id} encontró ${decoded.length} resultados para "$query"');
        return List<Map<String, dynamic>>.from(decoded.map((item) => Map<String, dynamic>.from(item)));
      }
    } catch (e) {
      debugPrint('❌ [PLUGIN_SEARCH_ERROR] Error buscando en ${plugin.id}: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> executeGetStreamUrl(PluginModel plugin, String rawUrl) async {
    await init();
    try {
      final code = '''
        (function() {
          ${plugin.sourceCode}
          if (typeof plugin !== 'undefined' && typeof plugin.getStreamUrl === 'function') {
            var res = plugin.getStreamUrl("$rawUrl");
            return JSON.stringify(res || {});
          }
          return JSON.stringify({});
        })();
      ''';

      final resultStr = await _evalJs(code);
      final decoded = jsonDecode(resultStr);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      debugPrint('❌ [PLUGIN_STREAM_ERROR] Error en getStreamUrl en ${plugin.id}: $e');
    }
    return {'url': rawUrl, 'headers': {}};
  }

  void dispose() {
    if (_initialized) {
      _jsRuntime.dispose();
      _initialized = false;
    }
  }
}
