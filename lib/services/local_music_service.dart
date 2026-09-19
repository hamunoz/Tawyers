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
import 'package:hive_flutter/hive_flutter.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/logger_service.dart';
import 'package:permission_handler/permission_handler.dart';

final LocalMusicService localMusicService = LocalMusicService();

class LocalMusicService {
  factory LocalMusicService() => _instance;
  LocalMusicService._internal();
  static final LocalMusicService _instance = LocalMusicService._internal();

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

  Future<void> scanLocalMusicFolder(String folderPath) async {
    try {
      await _requestStoragePermissions();

      final realPath = _normalizeFolderPath(folderPath);
      debugPrint('📂 [LOCAL_MUSIC] Normalizada ruta SAF: "$folderPath" -> "$realPath"');

      final directory = Directory(realPath);
      if (!await directory.exists()) {
        debugPrint('⚠️ [LOCAL_MUSIC] La carpeta no existe en disco: $realPath. Escaneando carpetas públicas...');
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
            final fileName = path.split('/').last;
            final title = fileName.contains('.')
                ? fileName.substring(0, fileName.lastIndexOf('.'))
                : fileName;

            localSongs.add({
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
            });
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
      debugPrint('📂 [LOCAL_MUSIC] Escaneo completado: ${localSongs.length} archivos de audio encontrados en $realPath');
    } catch (e) {
      _logger.log('Error escaneando carpeta local $folderPath', error: e);
      await _scanDefaultPublicFolders();
    }
  }

  Future<void> _scanDefaultPublicFolders() async {
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
                final fileName = path.split('/').last;
                final title = fileName.contains('.')
                    ? fileName.substring(0, fileName.lastIndexOf('.'))
                    : fileName;

                localSongs.add({
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
                });
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
