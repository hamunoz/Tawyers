/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/playlist_image_picker.dart';

void showCreatePlaylistDialog(
  BuildContext context, {
  dynamic songToAdd,
  List<dynamic>? songsToAdd,
}) {
  var id = '';
  var customPlaylistName = '';
  var isYouTubeMode = songToAdd == null && songsToAdd == null;
  String? imageUrl;
  String? imageBase64;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, dialogSetState) {
          final colorScheme = Theme.of(context).colorScheme;

          Future<void> _pickImage() async {
            final result = await pickImage();
            if (result != null) {
              dialogSetState(() {
                imageBase64 = result;
                imageUrl = null;
              });
            }
          }

          Widget _imagePreview() {
            return buildImagePreview(
              imageBase64: imageBase64,
              imageUrl: imageUrl,
            );
          }

          return AlertDialog(
            icon: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                FluentIcons.add_24_filled,
                color: colorScheme.primary,
                size: 32,
              ),
            ),
            title: Text(
              context.l10n!.addPlaylist,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
            ),
            titleTextStyle: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (songToAdd == null && songsToAdd == null)
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                dialogSetState(() {
                                  isYouTubeMode = true;
                                  id = '';
                                  customPlaylistName = '';
                                  imageUrl = null;
                                  imageBase64 = null;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isYouTubeMode
                                      ? colorScheme.primaryContainer
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      FluentIcons.globe_20_filled,
                                      size: 20,
                                      color: isYouTubeMode
                                          ? colorScheme.onPrimaryContainer
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'YouTube',
                                      style: TextStyle(
                                        color: isYouTubeMode
                                            ? colorScheme.onPrimaryContainer
                                            : colorScheme.onSurfaceVariant,
                                        fontWeight: isYouTubeMode
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                dialogSetState(() {
                                  isYouTubeMode = false;
                                  id = '';
                                  customPlaylistName = '';
                                  imageUrl = null;
                                  imageBase64 = null;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: !isYouTubeMode
                                      ? colorScheme.primaryContainer
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      FluentIcons.person_20_filled,
                                      size: 20,
                                      color: !isYouTubeMode
                                          ? colorScheme.onPrimaryContainer
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      context.l10n!.custom,
                                      style: TextStyle(
                                        color: !isYouTubeMode
                                            ? colorScheme.onPrimaryContainer
                                            : colorScheme.onSurfaceVariant,
                                        fontWeight: !isYouTubeMode
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (isYouTubeMode)
                    TextField(
                      decoration: InputDecoration(
                        labelText: context.l10n!.youtubePlaylistLinkOrId,
                        prefixIcon: Icon(
                          FluentIcons.link_20_regular,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerLow,
                      ),
                      onChanged: (value) {
                        id = value;
                      },
                    )
                  else ...[
                    TextField(
                      decoration: InputDecoration(
                        labelText: context.l10n!.customPlaylistName,
                        prefixIcon: Icon(
                          FluentIcons.text_field_20_regular,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerLow,
                      ),
                      autofocus: true,
                      onChanged: (value) {
                        customPlaylistName = value;
                      },
                    ),
                    if (imageBase64 == null) ...[
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                          labelText: context.l10n!.customPlaylistImgUrl,
                          prefixIcon: Icon(
                            FluentIcons.image_20_regular,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerLow,
                        ),
                        onChanged: (value) {
                          imageUrl = value;
                          imageBase64 = null;
                          dialogSetState(() {});
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (imageUrl == null) ...[
                      buildImagePickerRow(
                        context,
                        _pickImage,
                        imageBase64 != null,
                      ),
                      _imagePreview(),
                    ],
                  ],
                ],
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: <Widget>[
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colorScheme.outline),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(context.l10n!.cancel),
              ),
              FilledButton.icon(
                onPressed: () async {
                  if (isYouTubeMode && id.isNotEmpty) {
                    final result = await addUserPlaylist(id, context);
                    if (context.mounted) showToast(context, result);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  } else if (!isYouTubeMode && customPlaylistName.isNotEmpty) {
                    final (result, newPlaylistId) = createCustomPlaylist(
                      customPlaylistName.trim(),
                      imageBase64 ?? imageUrl,
                      context,
                    );
                    if (songToAdd != null) {
                      if (context.mounted) {
                        final addResult = addSongInCustomPlaylist(
                          context,
                          newPlaylistId,
                          songToAdd,
                        );
                        showToast(context, addResult);
                      }
                    } else if (songsToAdd != null && songsToAdd.isNotEmpty) {
                      if (context.mounted) {
                        final addResult = addSongsInCustomPlaylist(
                          context,
                          newPlaylistId,
                          songsToAdd,
                        );
                        showToast(context, addResult);
                      }
                    } else {
                      if (context.mounted) showToast(context, result);
                    }
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  } else {
                    showToast(
                      context,
                      '${context.l10n!.provideIdOrNameError}.',
                    );
                  }
                },
                icon: const Icon(FluentIcons.add_20_filled),
                label: Text(context.l10n!.add),
              ),
            ],
          );
        },
      );
    },
  );
}

void showAddToPlaylistDialog(
  BuildContext context, {
  dynamic song,
  List<dynamic>? songs,
}) {
  String? selectedDestination; // Sin selección previa por defecto

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, dialogSetState) {
          final colorScheme = Theme.of(context).colorScheme;
          final topLevelPlaylists = getPlaylistsNotInFolders();

          return AlertDialog(
            icon: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                FluentIcons.album_add_24_filled,
                color: colorScheme.primary,
                size: 28,
              ),
            ),
            title: const Text(
              'Guardar en...',
              style: TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            content: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Opción 1: Raíz de la Librería (Liked Items)
                    Card(
                      elevation: 0,
                      color: selectedDestination == 'root'
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: selectedDestination == 'root'
                              ? colorScheme.primary
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: ListTile(
                        leading: Icon(
                          FluentIcons.heart_24_filled,
                          color: colorScheme.primary,
                        ),
                        title: const Text(
                          'Liked Items (Raíz de Librería)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: selectedDestination == 'root'
                            ? Icon(FluentIcons.checkmark_24_filled, color: colorScheme.primary)
                            : null,
                        onTap: () {
                          dialogSetState(() => selectedDestination = 'root');
                        },
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Opción 2: Playlists existentes del usuario
                    if (topLevelPlaylists.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Tus Listas Creadas:',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: colorScheme.outline,
                              ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...topLevelPlaylists.map((p) {
                        final pId = p['ytid']?.toString() ?? '';
                        final isSel = selectedDestination == pId;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Card(
                            elevation: 0,
                            color: isSel
                                ? colorScheme.tertiaryContainer
                                : colorScheme.surfaceContainerLow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSel
                                    ? colorScheme.tertiary
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: ListTile(
                              leading: Icon(
                                FluentIcons.text_bullet_list_24_filled,
                                color: colorScheme.tertiary,
                              ),
                              title: Text(
                                p['title'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              trailing: isSel
                                  ? Icon(FluentIcons.checkmark_24_filled, color: colorScheme.tertiary)
                                  : null,
                              onTap: () {
                                dialogSetState(() => selectedDestination = pId);
                              },
                            ),
                          ),
                        );
                      }),
                    ],

                    // Opción 3: Botón para crear nueva playlist
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        showCreatePlaylistDialog(
                          context,
                          songToAdd: song,
                          songsToAdd: songs,
                        );
                      },
                      icon: const Icon(FluentIcons.add_24_regular),
                      label: const Text('+ Crear Nueva Playlist'),
                    ),
                  ],
                ),
              ),
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n!.cancel),
              ),
              FilledButton(
                onPressed: selectedDestination == null
                    ? null
                    : () async {
                        Navigator.pop(context);
                        if (selectedDestination == 'root') {
                          if (song != null) {
                            final songMap = song is Map ? Map<String, dynamic>.from(song) : {};
                            final id = songMap['ytid']?.toString() ?? songMap['id']?.toString() ?? '';
                            final isRadio = songMap['isLive'] == true || id.contains(':');

                            if (isRadio) {
                              await addRadioStationToLiked(id, stationData: songMap);
                            } else if (id.isNotEmpty) {
                              await updateSongLikeStatus(id, true, songData: songMap);
                            }
                            if (context.mounted) {
                              showToast(context, 'Guardado en Liked Items');
                            }
                          }
                        } else {
                          if (song != null) {
                            showToast(
                              context,
                              addSongInCustomPlaylist(context, selectedDestination!, song),
                            );
                          } else if (songs != null && songs.isNotEmpty) {
                            showToast(
                              context,
                              addSongsInCustomPlaylist(context, selectedDestination!, songs),
                            );
                          }
                        }
                      },
                child: const Text('Aceptar'),
              ),
            ],
          );
        },
      );
    },
  );
}
