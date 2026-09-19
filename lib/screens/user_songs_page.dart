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
import 'package:musify/constants/app_constants.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart' show audioHandler;
import 'package:musify/models/radio_model.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/plugin_manager.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/song_filtering.dart';
import 'package:musify/widgets/confirmation_dialog.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/playlist_hero_artwork.dart';
import 'package:musify/widgets/playlist_page/empty_playlist_state.dart';
import 'package:musify/widgets/playlist_page/playlist_header.dart';
import 'package:musify/widgets/playlist_page/playlist_sliver_app_bar.dart';
import 'package:musify/widgets/playlist_page/search_bar_section.dart';
import 'package:musify/widgets/radio_station_card.dart';
import 'package:musify/widgets/song_bar.dart';
import 'package:musify/widgets/sort_chips.dart';

enum OfflineSortType { default_, title, artist, dateAdded }

class UserSongsPage extends StatefulWidget {
  const UserSongsPage({super.key, required this.page});

  final String page;

  @override
  State<UserSongsPage> createState() => _UserSongsPageState();
}

class _UserSongsPageState extends State<UserSongsPage> {
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier('');
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  List _getDisplayList(List songsList) {
    var list = filterSongsByQuery(songsList, _searchQueryNotifier.value);
    if (widget.page == 'offline') {
      list = _sortOfflineSongsLocal(list, _getCurrentOfflineSortType());
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchQueryNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = getTitle(widget.page, context);
    final icon = getIcon(widget.page);
    final isOfflineSongs = title == context.l10n!.offlineSongs;

    final isLikedItems = widget.page == 'liked';

    return Scaffold(
      body: Padding(
        padding: commonSingleChildScrollViewPadding,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            userLikedSongsList,
            userLikedRadioStationsData,
            userOfflineSongs,
            userRecentlyPlayedStreams,
            userRecentlyPlayed,
          ]),
          builder: (context, _) {
            final songsList = isLikedItems
                ? [...userLikedSongsList.value, ...userLikedRadioStationsData.value]
                : widget.page == 'offline'
                ? userOfflineSongs.value
                : widget.page == 'recentStreams'
                ? userRecentlyPlayedStreams.value
                : userRecentlyPlayed.value;

            return _buildCustomScrollView(
              title,
              icon,
              songsList.length,
              isOfflineSongs,
            );
          },
        ),
      ),
    );
  }

  OfflineSortType _getCurrentOfflineSortType() {
    return OfflineSortType.values.firstWhere(
      (e) => e.name == offlineSortSetting,
      orElse: () => OfflineSortType.default_,
    );
  }

  Widget _buildCustomScrollView(
    String title,
    IconData icon,
    int songsLength,
    bool isOfflineSongs,
  ) {
    return CustomScrollView(
      slivers: [
        PlaylistSliverAppBar(
          title: title,
          artwork: PlaylistHeroArtwork({'title': title}, cubeIcon: icon),
        ),
        SliverToBoxAdapter(
          child: _buildHeaderSection(title, icon, songsLength, isOfflineSongs),
        ),
        buildSongList(title),
        if (songsLength == 0)
          SliverToBoxAdapter(
            child: SizedBox(
              height:
                  MediaQuery.sizeOf(context).width >
                      MediaQuery.sizeOf(context).height
                  ? 320
                  : 280,
            ),
          ),
        const SliverMiniPlayerBottomSpace(),
      ],
    );
  }

  String getTitle(String page, BuildContext context) {
    return switch (page) {
      'liked' => 'Liked Items',
      'offline' => context.l10n!.offlineSongs,
      'recents' => 'History Song',
      'recentStreams' => 'History Streaming',
      _ => context.l10n!.playlist,
    };
  }

  IconData getIcon(String page) {
    return switch (page) {
      'liked' => FluentIcons.heart_24_regular,
      'offline' => FluentIcons.cloud_off_24_regular,
      'recents' => FluentIcons.history_24_regular,
      'recentStreams' => FluentIcons.live_24_regular,
      _ => FluentIcons.heart_24_regular,
    };
  }

  Widget _buildHeaderSection(
    String title,
    IconData icon,
    int songsLength,
    bool isOfflineSongs,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isRecents = widget.page == 'recents' || widget.page == 'recentStreams';

    return Column(
      children: [
        PlaylistHeader(
          title: title,
          songsLength: songsLength,
          showTitle: false,
        ),
        if (songsLength > 0 && widget.page != 'recentStreams') ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(FluentIcons.play_24_filled),
                    label: Text(context.l10n!.play),
                    onPressed: () {
                      final songsList = widget.page == 'liked'
                          ? userLikedSongsList.value
                          : widget.page == 'offline'
                          ? userOfflineSongs.value
                          : userRecentlyPlayed.value;
                      var sortedList = songsList;
                      if (isOfflineSongs) {
                        sortedList = _sortOfflineSongsLocal(
                          songsList,
                          _getCurrentOfflineSortType(),
                        );
                      }
                      final playlist = {
                        'ytid': '',
                        'title': title,
                        'source': 'user-created',
                        'list': sortedList,
                      };
                      audioHandler.playPlaylistSong(
                        playlist: playlist,
                        songIndex: 0,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.secondaryContainer,
                      foregroundColor: colorScheme.onSecondaryContainer,
                    ),
                    icon: const Icon(FluentIcons.arrow_shuffle_24_filled),
                    label: Text(context.l10n!.shuffle),
                    onPressed: () async {
                      final songs = widget.page == 'liked'
                          ? userLikedSongsList.value
                          : widget.page == 'offline'
                          ? userOfflineSongs.value
                          : userRecentlyPlayed.value;
                      final shuffledSongs = List.from(songs)..shuffle();
                      final playlist = {
                        'ytid': '',
                        'title': title,
                        'source': 'user-created',
                        'list': shuffledSongs,
                      };
                      await audioHandler.playPlaylistSong(
                        playlist: playlist,
                        songIndex: 0,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
        if (isRecents) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [_buildClearRecentsButton(colorScheme.primary)],
          ),
        ],
        if (isOfflineSongs && songsLength > 1) ...[
          const SizedBox(height: 20),
          SortChips<OfflineSortType>(
            currentSortType: _getCurrentOfflineSortType(),
            sortTypes: OfflineSortType.values,
            sortTypeToString: _getSortTypeDisplayText,
            onSelected: (type) {
              setState(() {
                addOrUpdateData<String>(
                  'settings',
                  'offlineSortType',
                  type.name,
                );
                offlineSortSetting = type.name;
              });
            },
          ),
        ],
        if (songsLength > 0) ...[
          const SizedBox(height: 16),
          SearchBarSection(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onSearchChanged: (value) => _searchQueryNotifier.value = value,
            labelText: context.l10n!.search,
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildClearRecentsButton(Color primaryColor) {
    return IconButton.filledTonal(
      icon: Icon(FluentIcons.delete_24_regular, color: primaryColor),
      iconSize: 24,
      onPressed: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return ConfirmationDialog(
              confirmationMessage: context.l10n!.clearRecentlyPlayedQuestion,
              submitMessage: context.l10n!.clear,
              isDangerous: true,
              onCancel: () => Navigator.pop(context),
              onSubmit: () {
                Navigator.pop(context);
                if (widget.page == 'recentStreams') {
                  userRecentlyPlayedStreams.value = [];
                  addOrUpdateData<List>('user', 'recentlyPlayedStreams', []);
                } else {
                  userRecentlyPlayed.value = [];
                  addOrUpdateData<List>('user', 'recentlyPlayedSongs', []);
                }
                showToast(context, context.l10n!.recentlyPlayedMsg);
              },
            );
          },
        );
      },
    );
  }

  Widget buildSongList(String title) {
    final isLikedSongs = title == context.l10n!.likedSongs;
    final isOfflineSongs = title == context.l10n!.offlineSongs;
    final isRecentStreams = widget.page == 'recentStreams';

    return ValueListenableBuilder<String>(
      valueListenable: _searchQueryNotifier,
      builder: (_, searchQuery, __) {
        final songsList = widget.page == 'liked'
            ? userLikedSongsList.value
            : widget.page == 'offline'
            ? userOfflineSongs.value
            : widget.page == 'recentStreams'
            ? userRecentlyPlayedStreams.value
            : userRecentlyPlayed.value;

        final isSearching = searchQuery.isNotEmpty;
        final displayList = _getDisplayList(songsList);

        if (displayList.isEmpty) {
          final emptyIcon = isLikedSongs
              ? FluentIcons.heart_24_regular
              : isRecentStreams
              ? FluentIcons.live_24_regular
              : FluentIcons.text_bullet_list_24_filled;
          return EmptyPlaylistState(
            icon: emptyIcon,
            message: context.l10n!.playlistEmpty,
          );
        }

        if (isRecentStreams) {
          return SliverList.builder(
            itemCount: displayList.length,
            itemBuilder: (context, index) {
              final map = displayList[index] as Map;
              final streamId = map['id']?.toString() ?? '';
              final station = RadioStation(
                id: streamId,
                name: map['title']?.toString() ?? 'Stream',
                image: map['image']?.toString() ?? '',
                streamUrl: map['streamUrl']?.toString() ?? '',
                genre: map['artist']?.toString(),
              );

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Dismissible(
                  key: ValueKey('stream_$streamId'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      FluentIcons.delete_24_regular,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  onDismissed: (_) {
                    final updated = List.from(userRecentlyPlayedStreams.value)
                      ..removeWhere((i) => i['id'] == streamId);
                    userRecentlyPlayedStreams.value = updated;
                    addOrUpdateData<List>('user', 'recentlyPlayedStreams', updated);
                  },
                  child: RadioStationCard(
                    station: station,
                    onPressed: () async {
                      final resolvedInfo = await pluginManager.getStreamUrlForStation(
                        station.id,
                        station.streamUrl,
                      );
                      final finalUrl = resolvedInfo['url']?.toString() ?? station.streamUrl;

                      await audioHandler.playRadioStream(
                        id: station.id,
                        name: station.name,
                        streamUrl: finalUrl,
                        image: station.image,
                        genre: station.genre,
                      );
                    },
                  ),
                ),
              );
            },
          );
        }

        var sortedList = songsList;
        if (isOfflineSongs) {
          sortedList = _sortOfflineSongsLocal(
            songsList,
            _getCurrentOfflineSortType(),
          );
        }

        final isRecentsSong = widget.page == 'recents';

        return SliverList(
          key: isOfflineSongs && !isSearching
              ? ValueKey(_getCurrentOfflineSortType())
              : null,
          delegate: SliverChildBuilderDelegate((context, index) {
            final song = displayList[index];
            final songMap = song is Map ? Map<String, dynamic>.from(song) : {};
            final isStream = songMap['isLive'] == true || (songMap['id']?.toString().contains(':') ?? false);

            if (isStream) {
              final station = RadioStation(
                id: songMap['id']?.toString() ?? '',
                name: songMap['title']?.toString() ?? 'Stream',
                image: songMap['image']?.toString() ?? songMap['highResImage']?.toString() ?? '',
                streamUrl: songMap['streamUrl']?.toString() ?? '',
                genre: songMap['artist']?.toString(),
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RadioStationCard(
                  station: station,
                  onPressed: () async {
                    final resolvedInfo = await pluginManager.getStreamUrlForStation(
                      station.id,
                      station.streamUrl,
                    );
                    final finalUrl = resolvedInfo['url']?.toString() ?? station.streamUrl;

                    await audioHandler.playRadioStream(
                      id: station.id,
                      name: station.name,
                      streamUrl: finalUrl,
                      image: station.image,
                      genre: station.genre,
                    );
                  },
                ),
              );
            }

            final borderRadius = getItemBorderRadius(index, displayList.length);
            return RepaintBoundary(
              child: SongBar(
                song,
                false,
                key: listItemKey('user_song_${widget.page}', index, song),
                onPlay: () {
                  audioHandler.playPlaylistSong(
                    playlist: {
                      'title': title,
                      'list': sortedList,
                    },
                    songIndex: index,
                  );
                },
                onRemove: isRecentsSong
                    ? () => removeFromRecentlyPlayed(song['ytid'])
                    : null,
                showMusicDuration: true,
                borderRadius: borderRadius,
              ),
            );
          }, childCount: displayList.length),
        );
      },
    );
  }

  String _getSortTypeDisplayText(OfflineSortType type) {
    return switch (type) {
      OfflineSortType.default_ => context.l10n!.default_,
      OfflineSortType.title => 'Título',
      OfflineSortType.artist => context.l10n!.artist,
      OfflineSortType.dateAdded => context.l10n!.dateAdded,
    };
  }
}

List _sortOfflineSongsLocal(List songsList, OfflineSortType sortType) {
  final sortedList = List.from(songsList);

  switch (sortType) {
    case OfflineSortType.title:
      sortedList.sort(
        (a, b) => (a['title'] ?? '').toString().toLowerCase().compareTo(
          (b['title'] ?? '').toString().toLowerCase(),
        ),
      );
    case OfflineSortType.artist:
      sortedList.sort(
        (a, b) => (a['artist'] ?? '').toString().toLowerCase().compareTo(
          (b['artist'] ?? '').toString().toLowerCase(),
        ),
      );
    case OfflineSortType.dateAdded:
      sortedList.sort((a, b) {
        final aDate = a['dateAdded'] as DateTime?;
        final bDate = b['dateAdded'] as DateTime?;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
    case OfflineSortType.default_:
      break;
  }

  return sortedList;
}
