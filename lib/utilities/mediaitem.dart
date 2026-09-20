/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'package:audio_service/audio_service.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/utilities/media_duration.dart';

Map mediaItemToMap(MediaItem mediaItem) {
  final extras = mediaItem.extras;
  return {
    'id': mediaItem.id,
    'ytid': extras?['ytid'],
    'album': mediaItem.album.toString(),
    'artist': mediaItem.artist.toString(),
    'title': mediaItem.title,
    'artistId': extras?['artistId'],
    'videoAuthor': extras?['videoAuthor'],
    'highResImage': extras?['highResImage'] ?? mediaItem.artUri?.toString() ?? '',
    'lowResImage': extras?['lowResImage'],
    'isLive': extras?['isLive'] ?? false,
    if (mediaItem.duration case final duration?) 'duration': duration.inSeconds,
  };
}

MediaItem mapToMediaItem(Map song) {
  final ytid = song['ytid']?.toString();
  final offlineSong = ytid != null
      ? getOfflineSongByYtid(ytid)
      : <String, dynamic>{};
  final isOffline = offlineSong.isNotEmpty;

  final imageStr = song['highResImage']?.toString() ??
      song['image']?.toString() ??
      (isOffline ? offlineSong['artworkPath']?.toString() : null) ??
      '';

  late final Uri artUri;
  if (imageStr.startsWith('http://') || imageStr.startsWith('https://')) {
    artUri = Uri.parse(imageStr);
  } else if (imageStr.isNotEmpty && (imageStr.startsWith('/') || imageStr.startsWith('file://'))) {
    artUri = Uri.file(imageStr.replaceFirst('file://', ''));
  } else {
    artUri = Uri.file('');
  }

  return MediaItem(
    id: song['id']?.toString() ?? song['ytid']?.toString() ?? '',
    artist: song['artist']?.toString().trim() ?? 'Música Local',
    title: song['title']?.toString() ?? song['name']?.toString() ?? 'Pista Local',
    artUri: artUri,
    duration: readMediaDuration(song['duration']),
    extras: {
      'lowResImage': song['lowResImage'],
      'ytid': song['ytid'] ?? song['id'],
      'artistId': song['artistId'],
      'videoAuthor': song['videoAuthor'],
      'isLive': song['isLive'] ?? false,
      'highResImage': imageStr,
      'artWorkPath': imageStr,
    },
  );
}

bool durationEquals(Duration? prev, Duration? curr) {
  if (prev == curr) return true;
  if (prev == null || curr == null) return prev == curr;

  return (prev - curr).abs() < const Duration(seconds: 1);
}
