/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'package:get_it/get_it.dart';
import 'package:musify/services/listening_stats_service.dart';
import 'package:musify/services/local_music_service.dart';
import 'package:musify/services/logger_service.dart';
import 'package:musify/services/playlist_download_service.dart';
import 'package:musify/services/plugin_manager.dart';
import 'package:musify/services/proxy_manager.dart';

final GetIt locator = GetIt.instance;

Future<void> setupServiceLocator() async {
  if (!locator.isRegistered<Logger>()) {
    locator.registerLazySingleton<Logger>(Logger.new);
  }

  if (!locator.isRegistered<PluginManager>()) {
    locator.registerLazySingleton<PluginManager>(PluginManager.new);
  }

  if (!locator.isRegistered<LocalMusicService>()) {
    locator.registerLazySingleton<LocalMusicService>(LocalMusicService.new);
  }

  if (!locator.isRegistered<ListeningStatsService>()) {
    locator.registerLazySingleton<ListeningStatsService>(ListeningStatsService.new);
  }

  if (!locator.isRegistered<OfflinePlaylistService>()) {
    locator.registerLazySingleton<OfflinePlaylistService>(OfflinePlaylistService.new);
  }

  if (!locator.isRegistered<ProxyManager>()) {
    locator.registerLazySingleton<ProxyManager>(ProxyManager.new);
  }
}
