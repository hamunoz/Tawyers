/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/models/radio_model.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/utilities/artwork_provider.dart';
import 'package:musify/utilities/playlist_dialogs.dart';
import 'package:musify/widgets/shapes/eight_leaf_clover_shape.dart';

class RadioStationCard extends StatefulWidget {
  const RadioStationCard({
    super.key,
    required this.station,
    required this.onPressed,
    this.onFavoritesChanged,
    this.onRemove,
  });

  final RadioStation station;
  final VoidCallback onPressed;
  final VoidCallback? onFavoritesChanged;
  final VoidCallback? onRemove;

  @override
  State<RadioStationCard> createState() => _RadioStationCardState();
}

class _RadioStationCardState extends State<RadioStationCard> {
  late final ValueNotifier<bool> _isFavorited = ValueNotifier<bool>(
    isItemSavedInLibrary(widget.station.id),
  );

  @override
  void initState() {
    super.initState();
    userLikedRadioStations.addListener(_onFavoritesUpdated);
    userCustomPlaylists.addListener(_onFavoritesUpdated);
    userPlaylistFolders.addListener(_onFavoritesUpdated);
  }

  void _onFavoritesUpdated() {
    final newStatus = isItemSavedInLibrary(widget.station.id);
    if (_isFavorited.value != newStatus) {
      _isFavorited.value = newStatus;
    }
  }

  @override
  void dispose() {
    userLikedRadioStations.removeListener(_onFavoritesUpdated);
    userCustomPlaylists.removeListener(_onFavoritesUpdated);
    userPlaylistFolders.removeListener(_onFavoritesUpdated);
    _isFavorited.dispose();
    super.dispose();
  }

  Future<void> _handleFavoriteTap() async {
    final wasFavorited = _isFavorited.value;

    if (wasFavorited) {
      _isFavorited.value = false;
      try {
        await removeRadioStationFromLiked(widget.station.id);
        widget.onFavoritesChanged?.call();
      } catch (e) {
        _isFavorited.value = true;
      }
    } else {
      showAddToPlaylistDialog(
        context,
        song: widget.station.toMap(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image(
                  image: ArtworkProvider.get(widget.station.image),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 56,
                    height: 56,
                    color: colorScheme.primaryContainer,
                    child: Icon(
                      FluentIcons.sound_source_24_regular,
                      color: colorScheme.onPrimaryContainer,
                      size: 26,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.station.name,
                      style: textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.station.genre ?? 'Radio Station',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              ValueListenableBuilder<bool>(
                valueListenable: _isFavorited,
                builder: (context, isFavorited, _) {
                  return IconButton.filledTonal(
                    onPressed: _handleFavoriteTap,
                    icon: Icon(
                      isFavorited
                          ? FluentIcons.heart_24_filled
                          : FluentIcons.heart_24_regular,
                      size: 18,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: isFavorited
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                      foregroundColor: isFavorited
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                      minimumSize: const Size(36, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  );
                },
              ),
              const SizedBox(width: 5),
              EightLeafClover(
                size: 48,
                color: colorScheme.secondaryContainer,
                onTap: widget.onPressed,
                child: Icon(
                  FluentIcons.play_24_filled,
                  size: 18,
                  color: colorScheme.primary,
                ),
              ),
              if (widget.onRemove != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(FluentIcons.delete_24_regular, size: 20),
                  color: colorScheme.error,
                  onPressed: widget.onRemove,
                  tooltip: 'Eliminar de la lista',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
