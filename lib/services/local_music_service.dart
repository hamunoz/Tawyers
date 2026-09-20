/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/logger_service.dart';
import 'package:permission_handler/permission_handler.dart';

final LocalMusicService localMusicService = LocalMusicService();

class LocalMusicService {
  factory LocalMusicService() => _instance;
  LocalMusicService._internal();
  static final LocalMusicService _instance = LocalMusicService._internal();

  static const MethodChannel _platform = MethodChannel('com.tawyers.player/mediastore');
  final ValueNotifier<String> selectedFolderNotifier = ValueNotifier('');
  final Logger _logger = Logger();
  bool _initialized = false;

  final Set<String> _supportedExtensions = {
    '.mp3',
    '.m4a',
    '.m4b',
    '.m4v',
    '.webm',
    '.flac',
    '.wav',
    '.aac',
    '.ogg',
    '.opus',
    '.mp4',
    '.3gp',
  };

  Future<void> init() async {
    if (_initialized) return;
    try {
      final box = await Hive.openBox('settings');
      final savedFolder = box.get('local_music_folder', defaultValue: '') as String;
      selectedFolderNotifier.value = savedFolder;

      if (savedFolder.isNotEmpty) {
        await scanLocalMusicFolder(savedFolder);
      } else {
        await _scanDefaultPublicFolders();
      }
      _initialized = true;
    } catch (e) {
      _logger.log('Error inicializando LocalMusicService', error: e);
    }
  }

  Future<bool> _requestStoragePermissions() async {
    if (kIsWeb) return true;
    if (Platform.isAndroid) {
      try {
        debugPrint('📂 [LOCAL_MUSIC] Solicitando permisos de almacenamiento a Android OS...');
        final audioStatus = await Permission.audio.request();
        if (audioStatus.isGranted) return true;

        final storageStatus = await Permission.storage.request();
        if (storageStatus.isGranted) return true;

        final manageStatus = await Permission.manageExternalStorage.request();
        if (manageStatus.isGranted) return true;
      } catch (e) {
        debugPrint('⚠️ [LOCAL_MUSIC] Advertencia solicitando permisos: $e');
      }
    }
    return true;
  }

  Future<List<Map<String, dynamic>>> queryAndroidMediaStore() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _requestStoragePermissions();
        final result = await _platform.invokeMethod('queryLocalSongs');
        if (result != null) {
          final list = result.map((e) => Map<String, dynamic>.from(e)).toList();
          debugPrint('⚡ [MEDIASTORE_KOTLIN] ${list.length} canciones cargadas en <10ms desde MediaStore nativo!');
          return list;
        }
      } catch (e) {
        debugPrint('⚠️ [MEDIASTORE_KOTLIN] Error consultando MediaStore nativo: $e');
      }
    }
    return [];
  }

  Future<String?> pickAndScanFolder() async {
    try {
      await _requestStoragePermissions();

      final selectedDirectory = await FilePicker.getDirectoryPath();
      if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
        final box = await Hive.openBox('settings');
        await box.put('local_music_folder', selectedDirectory);
        selectedFolderNotifier.value = selectedDirectory;

        await scanLocalMusicFolder(selectedDirectory);
        return selectedDirectory;
      }
    } catch (e) {
      _logger.log('Error seleccionando carpeta local', error: e);
    }
    return null;
  }

  String _normalizeFolderPath(String path) {
    if (path.isEmpty) return '/storage/emulated/0/Music';

    final decoded = Uri.decodeFull(path);
    if (decoded.contains('primary:') || decoded.contains('primary%3A')) {
      final idx = decoded.indexOf('primary:');
      final sub = idx != -1
          ? decoded.substring(idx + 8)
          : decoded.substring(decoded.indexOf('primary%3A') + 10);
      return '/storage/emulated/0/${sub.replaceAll('%2F', '/')}';
    }

    if (decoded.startsWith('content://')) {
      return '/storage/emulated/0/Music';
    }

    return decoded;
  }

  Map<String, dynamic> _extractFileBasics(File file) {
    final path = file.path;
    final fileName = path.split('/').last;
    var title = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    title = title.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

    return {
      'id': 'local_${path.hashCode}',
      'ytid': 'local_${path.hashCode}',
      'title': title,
      'name': title,
      'artist': 'Música Local',
      'album': 'Archivos Locales',
      'image': '',
      'highResImage': '',
      'audioUrl': path,
      'audioPath': path,
      'streamUrl': path,
      'isLocal': true,
      'isOffline': true,
      'duration': 0,
    };
  }

  Future<void> scanLocalMusicFolder(String folderPath) async {
    try {
      await _requestStoragePermissions();

      // En Android intentamos primero la consulta nativa rápida MediaStore
      if (!kIsWeb && Platform.isAndroid) {
        final nativeSongs = await queryAndroidMediaStore();
        if (nativeSongs.isNotEmpty) {
          userOfflineSongs.value = nativeSongs;
          final noBackupBox = await Hive.openBox('userNoBackup');
          await noBackupBox.put('offlineSongs', nativeSongs);
          return;
        }
      }

      final realPath = _normalizeFolderPath(folderPath);
      debugPrint('📂 [LOCAL_MUSIC] Escaneo por sistema de archivos: "$realPath"');

      final directory = Directory(realPath);
      if (!await directory.exists()) {
        await _scanDefaultPublicFolders();
        return;
      }

      final localSongs = <Map<String, dynamic>>[];

      await for (final entity in directory.list(recursive: true, followLinks: false).handleError((e) {
        debugPrint('⚠️ [LOCAL_MUSIC] Ignorando subcarpeta restringida: $e');
      })) {
        if (entity is File) {
          final path = entity.path;
          final lowerPath = path.toLowerCase();
          if (_supportedExtensions.any(lowerPath.endsWith)) {
            localSongs.add(_extractFileBasics(entity));
          }
        }
      }

      if (localSongs.isEmpty && realPath != '/storage/emulated/0/Music') {
        await _scanDefaultPublicFolders();
        return;
      }

      userOfflineSongs.value = localSongs;
      final noBackupBox = await Hive.openBox('userNoBackup');
      await noBackupBox.put('offlineSongs', localSongs);
      debugPrint('📂 [LOCAL_MUSIC] Escaneo por archivos completado: ${localSongs.length} archivos en $realPath');
    } catch (e) {
      _logger.log('Error escaneando carpeta local $folderPath', error: e);
      await _scanDefaultPublicFolders();
    }
  }

  Future<void> _scanDefaultPublicFolders() async {
    if (!kIsWeb && Platform.isAndroid) {
      final nativeSongs = await queryAndroidMediaStore();
      if (nativeSongs.isNotEmpty) {
        userOfflineSongs.value = nativeSongs;
        final noBackupBox = await Hive.openBox('userNoBackup');
        await noBackupBox.put('offlineSongs', nativeSongs);
        return;
      }
    }

    final candidateFolders = [
      '/storage/emulated/0/Music',
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Audio',
      '/sdcard/Music',
      '/sdcard/Download',
    ];

    final localSongs = <Map<String, dynamic>>[];

    for (final folderPath in candidateFolders) {
      try {
        final dir = Directory(folderPath);
        if (await dir.exists()) {
          await for (final entity in dir.list(recursive: true, followLinks: false).handleError((_) {})) {
            if (entity is File) {
              final path = entity.path;
              final lowerPath = path.toLowerCase();
              if (_supportedExtensions.any(lowerPath.endsWith)) {
                localSongs.add(_extractFileBasics(entity));
              }
            }
          }
        }
      } catch (_) {}
    }

    userOfflineSongs.value = localSongs;
    final noBackupBox = await Hive.openBox('userNoBackup');
    await noBackupBox.put('offlineSongs', localSongs);
    debugPrint('📂 [LOCAL_MUSIC] Escaneo público por defecto completado: ${localSongs.length} archivos encontrados');
  }
}
