package com.gokadzev.musify

import android.content.ContentUris
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.util.Size
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity : FlutterActivity() {
  private val CHANNEL = "com.tawyers.player/mediastore"

  override fun onCreate(savedInstanceState: Bundle?) {
    WindowCompat.setDecorFitsSystemWindows(window, false)

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      splashScreen.setOnExitAnimationListener { splashScreenView -> splashScreenView.remove() }
    }

    super.onCreate(savedInstanceState)
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
      when (call.method) {
        "queryLocalSongs" -> {
          try {
            val songs = queryMediaStoreSongs()
            result.success(songs)
          } catch (e: Exception) {
            result.error("MEDIASTORE_ERROR", e.message, null)
          }
        }
        "getAlbumArtwork" -> {
          try {
            val songId = call.argument<Number>("songId")?.toLong() ?: 0L
            val artworkBytes = getAlbumArtworkBytes(songId)
            result.success(artworkBytes)
          } catch (e: Exception) {
            result.success(null)
          }
        }
        else -> result.notImplemented()
      }
    }
  }

  private fun queryMediaStoreSongs(): List<Map<String, Any?>> {
    val songsList = mutableListOf<Map<String, Any?>>()

    val projection = arrayOf(
      MediaStore.Audio.Media._ID,
      MediaStore.Audio.Media.TITLE,
      MediaStore.Audio.Media.ARTIST,
      MediaStore.Audio.Media.ALBUM,
      MediaStore.Audio.Media.ALBUM_ID,
      MediaStore.Audio.Media.DURATION,
      MediaStore.Audio.Media.DATA
    )

    val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0"
    val sortOrder = "${MediaStore.Audio.Media.TITLE} ASC"

    contentResolver.query(
      MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
      projection,
      selection,
      null,
      sortOrder
    )?.use { cursor ->
      val idCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
      val titleCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
      val artistCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
      val albumCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
      val albumIdCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
      val durationCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
      val dataCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)

      while (cursor.moveToNext()) {
        val id = cursor.getLong(idCol)
        val albumId = cursor.getLong(albumIdCol)
        val rawTitle = cursor.getString(titleCol) ?: "Pista Local"
        val rawArtist = cursor.getString(artistCol)
        val artist = if (rawArtist.isNullOrEmpty() || rawArtist == "<unknown>") "Música Local" else rawArtist
        val album = cursor.getString(albumCol) ?: "Archivos Locales"
        val durationMs = cursor.getLong(durationCol)
        val durationSec = (durationMs / 1000).toInt()
        val dataPath = cursor.getString(dataCol) ?: ""

        val coverPath = getAlbumArtworkPath(id, albumId)
        val title = rawTitle.replace("_", " ").replace(Regex("\\s+"), " ").trim()

        songsList.add(
          mapOf(
            "id" to "local_$id",
            "ytid" to "local_$id",
            "rawId" to id,
            "title" to title,
            "name" to title,
            "artist" to artist,
            "album" to album,
            "image" to coverPath,
            "highResImage" to coverPath,
            "audioUrl" to dataPath,
            "audioPath" to dataPath,
            "streamUrl" to dataPath,
            "isLocal" to true,
            "isOffline" to true,
            "duration" to durationSec
          )
        )
      }
    }

    return songsList
  }

  private fun getAlbumArtworkPath(songId: Long, albumId: Long): String {
    try {
      val coverFile = File(cacheDir, "cover_album_$albumId.jpg")
      if (coverFile.exists() && coverFile.length() > 0) {
        return coverFile.absolutePath
      }

      val contentUri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, songId)
      val bitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        contentResolver.loadThumbnail(contentUri, Size(300, 300), null)
      } else {
        null
      }

      if (bitmap != null) {
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 85, stream)
        val bytes = stream.toByteArray()
        coverFile.writeBytes(bytes)
        return coverFile.absolutePath
      }
    } catch (e: Exception) {
      // Ignore
    }
    return ""
  }

  private fun getAlbumArtworkBytes(songId: Long): ByteArray? {
    if (songId <= 0L) return null
    return try {
      val contentUri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, songId)
      val bitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        contentResolver.loadThumbnail(contentUri, Size(300, 300), null)
      } else {
        null
      }
      if (bitmap != null) {
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 85, stream)
        stream.toByteArray()
      } else null
    } catch (e: Exception) {
      null
    }
  }
}
