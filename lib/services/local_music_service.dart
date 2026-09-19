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
    '.flac',
    '.wav',
    '.aac',
    '.ogg',
  };

  Future<void> init() async {
    if (_initialized) return;
    try {
      final box = await Hive.openBox('settings');
      final savedFolder = box.get('local_music_folder', defaultValue: '') as String;
      selectedFolderNotifier.value = savedFolder;

      if (savedFolder.isNotEmpty) {
        await scanLocalMusicFolder(savedFolder);
      }
      _initialized = true;
    } catch (e) {
      _logger.log('Error inicializando LocalMusicService', error: e);
    }
  }

  Future<String?> pickAndScanFolder() async {
    try {
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

  Future<void> scanLocalMusicFolder(String folderPath) async {
    try {
      final directory = Directory(folderPath);
      if (!await directory.exists()) return;

      final localSongs = <Map<String, dynamic>>[];
      final entities = directory.listSync(recursive: true, followLinks: false);

      for (final entity in entities) {
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
              'artist': 'Música Local',
              'album': 'Archivos Locales',
              'image': '',
              'highResImage': '',
              'audioUrl': path,
              'audioPath': path,
              'isLocal': true,
              'isOffline': true,
              'duration': 0,
            });
          }
        }
      }

      userOfflineSongs.value = localSongs;
      final noBackupBox = await Hive.openBox('userNoBackup');
      await noBackupBox.put('offlineSongs', localSongs);
    } catch (e) {
      _logger.log('Error escaneando carpeta local $folderPath', error: e);
    }
  }
}
