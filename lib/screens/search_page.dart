/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/models/radio_model.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/plugin_manager.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/song_filtering.dart';
import 'package:musify/widgets/artist_bar.dart';
import 'package:musify/widgets/confirmation_dialog.dart';
import 'package:musify/widgets/custom_bar.dart';
import 'package:musify/widgets/custom_search_bar.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/playlist_bar.dart';
import 'package:musify/widgets/radio_station_card.dart';
import 'package:musify/widgets/section_title.dart';
import 'package:musify/widgets/song_bar.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

final ValueNotifier<List> searchHistoryNotifier = ValueNotifier<List>(
  Hive.box('user').get('searchHistory', defaultValue: []),
);

void reloadSearchHistoryFromStorage() {
  searchHistoryNotifier.value = Hive.box('user')
      .get('searchHistory', defaultValue: []);
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchBar = TextEditingController();
  final FocusNode _inputNode = FocusNode();
  final ValueNotifier<bool> _fetchingSongs = ValueNotifier(false);
  int maxSongsInList = 15;
  List<dynamic> _songsSearchResult = [];
  List<Map<String, dynamic>> _artistsSearchResult = [];
  List<dynamic> _albumsSearchResult = [];
  List<dynamic> _playlistsSearchResult = [];
  List<RadioStation> _radioStationsSearchResult = [];
  List<String> _suggestionsList = [];
  Timer? _debounce;
  int _latestSuggestionRequest = 0;
  int _latestSearchRequest = 0;

  // Selección múltiple de fuentes de búsqueda (Todas seleccionadas por defecto)
  final Set<String> _activeSearchSources = {
    'offline',
    'youtube',
    'iheartradio',
    'tunein',
    'iptv_audio',
    'radio_browser',
  };

  @override
  void initState() {
    super.initState();
    reloadSearchHistoryFromStorage();
    pluginManager.init();
  }

  @override
  void dispose() {
    _searchBar.dispose();
    _inputNode.dispose();
    _fetchingSongs.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _submitSearch([String? query]) async {
    _inputNode.unfocus();
    _suggestionsList = [];
    if (query != null) {
      _searchBar.text = query;
      _searchBar.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchBar.text.length),
      );
    }
    await search();
  }

  Future<void> search() async {
    _inputNode.unfocus();
    _suggestionsList = [];

    final query = _searchBar.text.trim();
    final requestId = ++_latestSearchRequest;

    if (query.isEmpty) {
      _songsSearchResult = [];
      _artistsSearchResult = [];
      _albumsSearchResult = [];
      _playlistsSearchResult = [];
      _radioStationsSearchResult = [];
      _suggestionsList = [];
      _fetchingSongs.value = false;
      if (mounted) setState(() {});
      return;
    }

    _fetchingSongs.value = true;

    // Timer de seguridad: Detiene el icono de carga tras 7 segundos máximo
    Timer(const Duration(seconds: 7), () {
      if (mounted && requestId == _latestSearchRequest && _fetchingSongs.value) {
        _fetchingSongs.value = false;
      }
    });

    _songsSearchResult = [];
    _artistsSearchResult = [];
    _albumsSearchResult = [];
    _playlistsSearchResult = [];
    _radioStationsSearchResult = [];

    // 1. Si está activo Offline, buscamos en canciones locales
    if (_activeSearchSources.contains('offline')) {
      final localSongs = filterSongsByQuery(userOfflineSongs.value, query);
      _songsSearchResult.addAll(localSongs);
    }

    // 2. Búsqueda en los plugins activos seleccionados
    final enabledPlugins = pluginManager.pluginsNotifier.value
        .where((p) => p.enabled && _activeSearchSources.contains(p.id))
        .toList();

    if (enabledPlugins.isNotEmpty) {
      final activePluginIds = enabledPlugins.map((p) => p.id).toList();
      unawaited(
        pluginManager.searchAllPlugins(query, pluginIds: activePluginIds).then((pluginResults) {
          if (mounted && requestId == _latestSearchRequest) {
            _fetchingSongs.value = false;
            if (pluginResults.isNotEmpty) {
              final pluginStations = pluginResults.map((map) {
                return RadioStation(
                  id: map['id']?.toString() ?? '',
                  name: map['title']?.toString() ?? map['name']?.toString() ?? 'Emisora',
                  image: map['image']?.toString() ?? '',
                  streamUrl: map['streamUrl']?.toString() ?? '',
                  genre: map['genre']?.toString() ?? map['artist']?.toString(),
                );
              }).where((s) => s.streamUrl.isNotEmpty).toList();

              setState(() {
                _radioStationsSearchResult = [..._radioStationsSearchResult, ...pluginStations];
              });
            }
          }
        }).catchError((_) {
          if (mounted && requestId == _latestSearchRequest) {
            _fetchingSongs.value = false;
          }
        }),
      );
    }

    if (!searchHistoryNotifier.value.contains(query)) {
      final updatedHistory = List.from(searchHistoryNotifier.value)
        ..insert(0, query);
      searchHistoryNotifier.value = updatedHistory;
      unawaited(addOrUpdateData<List>('user', 'searchHistory', updatedHistory));
    }

    // 3. Búsqueda en YouTube si está seleccionado
    if (_activeSearchSources.contains('youtube')) {
      try {
        final artistsFuture = searchArtists(query);

        Future<void> publishSongs() async {
          try {
            var songs = await fetchSongsList(query);
            if (!mounted || requestId != _latestSearchRequest) return;

            if (songs.isEmpty) {
              final artists = await artistsFuture;
              if (!mounted || requestId != _latestSearchRequest) return;
              if (_artistsSearchResult.isEmpty) {
                _artistsSearchResult = artists
                    .whereType<Map>()
                    .map(Map<String, dynamic>.from)
                    .toList();
              }
              if (_artistsSearchResult.isNotEmpty) {
                songs = await _fetchSongsForResolvedArtist(query);
              }
            }

            if (!mounted || requestId != _latestSearchRequest) return;
            _fetchingSongs.value = false;
            setState(() => _songsSearchResult = [..._songsSearchResult, ...songs]);
          } catch (e, stackTrace) {
            _fetchingSongs.value = false;
            logger.log(
              'Error while searching online songs',
              error: e,
              stackTrace: stackTrace,
            );
          }
        }

        unawaited(publishSongs());

        unawaited(
          searchArtists(query).then((artists) {
            if (!mounted || requestId != _latestSearchRequest) return;
            _fetchingSongs.value = false;
            setState(() {
              _artistsSearchResult = artists
                  .whereType<Map>()
                  .map(Map<String, dynamic>.from)
                  .toList();
            });
          }).catchError((e, stackTrace) {
            _fetchingSongs.value = false;
            logger.log('Error while searching online artists', error: e, stackTrace: stackTrace);
          }),
        );

        unawaited(
          getPlaylists(query: query, type: 'album').then((albums) {
            if (!mounted || requestId != _latestSearchRequest) return;
            _fetchingSongs.value = false;
            setState(() => _albumsSearchResult = albums);
          }).catchError((e, stackTrace) {
            _fetchingSongs.value = false;
            logger.log('Error while searching online albums', error: e, stackTrace: stackTrace);
          }),
        );

        unawaited(
          getPlaylists(query: query, type: 'playlist').then((playlists) {
            if (!mounted || requestId != _latestSearchRequest) return;
            _fetchingSongs.value = false;
            setState(() => _playlistsSearchResult = playlists);
          }).catchError((e, stackTrace) {
            _fetchingSongs.value = false;
            logger.log('Error while searching online playlists', error: e, stackTrace: stackTrace);
          }),
        );
      } catch (e, stackTrace) {
        _fetchingSongs.value = false;
        logger.log('Error while searching online songs', error: e, stackTrace: stackTrace);
      }
    } else {
      _fetchingSongs.value = false;
    }

    if (mounted) setState(() {});
  }

  Future<List<dynamic>> _fetchSongsForResolvedArtist(String query) async {
    final artistName = _artistsSearchResult.first['title']?.toString().trim();
    if (artistName == null || artistName.isEmpty) return [];

    final fallbackQueries = <String>{
      if (artistName.toLowerCase() != query.trim().toLowerCase()) artistName,
      '$artistName songs',
      '$artistName music',
    };

    for (final fallbackQuery in fallbackQueries) {
      final songs = await fetchSongsList(fallbackQuery);
      if (songs.isNotEmpty) return songs;
    }

    return [];
  }

  void _showSearchFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final activePlugins = pluginManager.pluginsNotifier.value
                .where((p) => p.enabled)
                .toList();

            final sources = [
              {
                'id': 'offline',
                'title': context.l10n!.offlineSongs,
                'icon': FluentIcons.folder_24_regular,
              },
              {
                'id': 'youtube',
                'title': 'YouTube Music',
                'icon': FluentIcons.play_24_regular,
              },
              ...activePlugins.map((p) => {
                    'id': p.id,
                    'title': p.name,
                    'icon': _getPluginIconData(p.type),
                  }),
            ];

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n!.searchSources,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    ...sources.map((src) {
                      final id = src['id'] as String;
                      final title = src['title'] as String;
                      final icon = src['icon'] as IconData;
                      final isSelected = _activeSearchSources.contains(id);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          elevation: 0,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surfaceContainerLow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              setModalState(() {
                                if (isSelected) {
                                  _activeSearchSources.remove(id);
                                } else {
                                  _activeSearchSources.add(id);
                                }
                              });
                              setState(() {});
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Icon(
                                    icon,
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.onPrimaryContainer
                                        : Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected
                                            ? Theme.of(context).colorScheme.onPrimaryContainer
                                            : Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      FluentIcons.checkmark_24_filled,
                                      color: Theme.of(context).colorScheme.primary,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          if (_searchBar.text.isNotEmpty) {
                            _submitSearch();
                          }
                        },
                        child: Text(
                          context.l10n!.applyFilters,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _getPluginIconData(String type) {
    switch (type) {
      case 'radio':
        return Icons.radio;
      case 'iptv_audio':
        return FluentIcons.live_24_regular;
      case 'music':
        return FluentIcons.music_note_1_24_regular;
      default:
        return FluentIcons.plug_connected_24_regular;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n!.search),
        actions: [
          IconButton(
            icon: const Icon(FluentIcons.options_24_regular),
            tooltip: context.l10n!.searchSources,
            onPressed: () => _showSearchFilterDialog(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: commonSingleChildScrollViewPadding,
        child: Column(
          children: <Widget>[
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                final bar = ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isWide ? 600 : double.infinity,
                  ),
                  child: CustomSearchBar(
                    loadingProgressNotifier: _fetchingSongs,
                    controller: _searchBar,
                    focusNode: _inputNode,
                    labelText: '${context.l10n!.search}...',
                    onChanged: (value) {
                      _debounce?.cancel();
                      final query = value;
                      final requestId = ++_latestSuggestionRequest;

                      if (query.isEmpty) {
                        _suggestionsList = [];
                        if (mounted) setState(() {});
                        return;
                      }

                      _debounce = Timer(
                        const Duration(milliseconds: 300),
                        () async {
                          final searchSuggestions = await getSearchSuggestions(
                            query,
                          );

                          if (!mounted ||
                              requestId != _latestSuggestionRequest ||
                              _searchBar.text != query) {
                            return;
                          }

                          _suggestionsList = List<String>.from(
                            searchSuggestions,
                          );
                          if (mounted) setState(() {});
                        },
                      );
                    },
                    onSubmitted: (String value) {
                      _submitSearch();
                    },
                  ),
                );
                if (isWide) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [bar],
                  );
                } else {
                  return bar;
                }
              },
            ),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child:
                  (_suggestionsList.isNotEmpty ||
                      (_songsSearchResult.isEmpty &&
                          _artistsSearchResult.isEmpty &&
                          _albumsSearchResult.isEmpty &&
                          _playlistsSearchResult.isEmpty &&
                          _radioStationsSearchResult.isEmpty))
                  ? ValueListenableBuilder<List>(
                      valueListenable: searchHistoryNotifier,
                      builder: (context, searchHistory, _) {
                        final items = _suggestionsList.isEmpty
                            ? searchHistory
                            : _suggestionsList;

                        return Column(
                          key: ValueKey(
                            'history-${_suggestionsList.length}-${_searchBar.text}-${searchHistory.length}',
                          ),
                          children: [
                            for (int index = 0; index < items.length; index++)
                              Builder(
                                builder: (context) {
                                  final query = items[index];
                                  return CustomBar(
                                    query.toString(),
                                    _suggestionsList.isEmpty
                                        ? FluentIcons.history_24_regular
                                        : FluentIcons.search_24_regular,
                                    onTap: () async {
                                      await _submitSearch(query.toString());
                                    },
                                    onLongPress:
                                        _suggestionsList.isEmpty &&
                                                searchHistory.contains(query)
                                            ? () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => ConfirmationDialog(
                                                    confirmationMessage: context
                                                        .l10n!
                                                        .removeSearchQueryQuestion,
                                                    submitMessage: context.l10n!.confirm,
                                                    onCancel: () => Navigator.pop(context),
                                                    onSubmit: () {
                                                      Navigator.pop(context);
                                                      final updatedHistory =
                                                          List.from(
                                                            searchHistory,
                                                          )..remove(query);
                                                      searchHistoryNotifier
                                                              .value =
                                                          updatedHistory;
                                                      unawaited(
                                                        addOrUpdateData<List>(
                                                          'user',
                                                          'searchHistory',
                                                          updatedHistory,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                );
                                              }
                                            : null,
                                  );
                                },
                              ),
                          ],
                        );
                      },
                    )
                  : _buildSearchResults(context, primaryColor),
            ),
            const MiniPlayerBottomSpace(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, Color primaryColor) {
    final widgets = <Widget>[];

    // Artists section
    if (_artistsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.artists,
          primaryColor,
          icon: FluentIcons.person_24_filled,
        ),
      );

      final artists = _artistsSearchResult.take(3).toList();
      for (var index = 0; index < artists.length; index++) {
        final artist = artists[index];
        final artistId = artist['ytid']?.toString() ?? '';

        widgets.add(
          ArtistBar(
            key: listItemKey('search_artist', index, artist),
            artist: artist,
            onTap: () {
              final encodedPath = Uri.encodeComponent(artistId);
              context.push(
                '${NavigationManager.searchPath}/artist/$encodedPath',
                extra: artist,
              );
            },
          ),
        );
      }
    }

    // Songs section
    if (_songsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.songs,
          primaryColor,
          icon: FluentIcons.music_note_1_24_filled,
        ),
      );

      final songsCount = _songsSearchResult.length > maxSongsInList
          ? maxSongsInList
          : _songsSearchResult.length;

      for (var index = 0; index < songsCount; index++) {
        final song = _songsSearchResult[index];
        final borderRadius = getItemBorderRadius(index, songsCount);

        widgets.add(
          SongBar(
            song,
            false,
            key: listItemKey('search_song', index, song),
            onPlay: () {
              audioHandler.playPlaylistSong(
                playlist: {
                  'title': 'Búsqueda',
                  'list': _songsSearchResult,
                },
                songIndex: index,
              );
            },
            showMusicDuration: true,
            borderRadius: borderRadius,
          ),
        );
      }
    }

    // Albums section
    if (_albumsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.albums,
          primaryColor,
          icon: FluentIcons.album_24_filled,
        ),
      );

      final albumsCount = _albumsSearchResult.length > maxSongsInList
          ? maxSongsInList
          : _albumsSearchResult.length;

      for (var index = 0; index < albumsCount; index++) {
        final playlist = _albumsSearchResult[index];
        final borderRadius = getItemBorderRadius(index, albumsCount);

        widgets.add(
          PlaylistBar(
            key: listItemKey('search_album', index, playlist),
            playlist['title'],
            playlistId: playlist['ytid'],
            playlistArtwork: playlist['image'],
            cubeIcon: FluentIcons.cd_16_filled,
            isAlbum: true,
            borderRadius: borderRadius,
          ),
        );
      }
    }

    // Playlists section
    if (_playlistsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.playlists,
          primaryColor,
          icon: FluentIcons.text_bullet_list_24_filled,
        ),
      );

      final playlistsCount = _playlistsSearchResult.length > maxSongsInList
          ? maxSongsInList
          : _playlistsSearchResult.length;

      for (var index = 0; index < playlistsCount; index++) {
        final playlist = _playlistsSearchResult[index];
        final isLast = index == playlistsCount - 1;
        final borderRadius = getItemBorderRadius(index, playlistsCount);

        widgets.add(
          Padding(
            padding: isLast ? commonListViewBottomPadding : EdgeInsets.zero,
            child: PlaylistBar(
              key: listItemKey('search_playlist', index, playlist),
              playlist['title'],
              playlistId: playlist['ytid'],
              playlistArtwork: playlist['image'],
              cubeIcon: FluentIcons.apps_list_24_filled,
              borderRadius: borderRadius,
            ),
          ),
        );
      }
    }

    // Radio Stations section
    if (_radioStationsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.radioStations,
          primaryColor,
          icon: FluentIcons.speaker_2_24_filled,
        ),
      );

      final stationsCount = _radioStationsSearchResult.length > maxSongsInList
          ? maxSongsInList
          : _radioStationsSearchResult.length;

      for (var index = 0; index < stationsCount; index++) {
        final station = _radioStationsSearchResult[index];
        final isLast = index == stationsCount - 1;

        widgets.add(
          Padding(
            padding: isLast ? commonListViewBottomPadding : EdgeInsets.zero,
            child: RadioStationCard(
              key: listItemKey('search_radio_station', index, station),
              station: station,
              onPressed: () async {
                final resolvedInfo = await pluginManager.getStreamUrlForStation(
                  station.id,
                  station.streamUrl,
                );
                final finalUrl = resolvedInfo['url']?.toString() ?? station.streamUrl;

                final success = await audioHandler.playRadioStream(
                  id: station.id,
                  name: station.name,
                  streamUrl: finalUrl,
                  image: station.image,
                  genre: station.genre,
                );
                if (!success && context.mounted) {
                  showToast(context, context.l10n!.failedPlayingRadio);
                }
              },
            ),
          ),
        );
      }
    }

    return Column(
      children: widgets,
    );
  }
}
