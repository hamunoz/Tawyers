/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/models/plugin_model.dart';
import 'package:musify/models/radio_model.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/listening_stats_service.dart';
import 'package:musify/services/local_music_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/plugin_manager.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/async_loader.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/listening_stats_utils.dart';
import 'package:musify/widgets/announcement_box.dart';
import 'package:musify/widgets/listening_recap_card.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/playlist_cube.dart';
import 'package:musify/widgets/radio_station_card.dart';
import 'package:musify/widgets/recommended_songs_section.dart';
import 'package:musify/widgets/section_header.dart';
import 'package:musify/widgets/song_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<List> _suggestedPlaylistsFuture;
  late Future<List> _recommendedSongsFuture;

  // Píldora/Tab seleccionada por defecto: 'offline'
  String _selectedTabId = 'offline';

  // Caché de contenido para plugins
  final Map<String, List<RadioStation>> _pluginStationsCache = {};
  final Map<String, bool> _pluginLoadingState = {};

  @override
  void initState() {
    super.initState();
    _suggestedPlaylistsFuture = getPlaylists(
      playlistsNum: recommendedCubesNumber,
    );
    _recommendedSongsFuture = getRecommendedSongs();
    externalRecommendations.addListener(_refreshRecommendedSongs);
    pluginManager.init();
    localMusicService.init();
  }

  @override
  void dispose() {
    externalRecommendations.removeListener(_refreshRecommendedSongs);
    super.dispose();
  }

  void _refreshRecommendedSongs() {
    if (!mounted) return;
    setState(() {
      _recommendedSongsFuture = getRecommendedSongs();
    });
  }

  Future<void> _loadPluginContent(String pluginId) async {
    if (_pluginStationsCache.containsKey(pluginId)) return;

    setState(() {
      _pluginLoadingState[pluginId] = true;
    });

    try {
      final stations = await pluginManager.getRadioStationsFromPlugin(pluginId);
      final mapped = stations.map((map) {
        return RadioStation(
          id: map['id']?.toString() ?? '',
          name: map['title']?.toString() ?? map['name']?.toString() ?? 'Emisora',
          image: map['image']?.toString() ?? '',
          streamUrl: map['streamUrl']?.toString() ?? '',
          genre: map['genre']?.toString() ?? map['artist']?.toString(),
        );
      }).where((s) => s.streamUrl.isNotEmpty).toList();

      if (mounted) {
        setState(() {
          _pluginStationsCache[pluginId] = mapped;
          _pluginLoadingState[pluginId] = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _pluginLoadingState[pluginId] = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlistHeight = MediaQuery.sizeOf(context).height * 0.25 / 1.1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tawyers'),
        actions: [
          IconButton(
            icon: const Icon(FluentIcons.plug_connected_24_regular),
            onPressed: () => context.push('/settings/plugins'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra superior de Píldoras / Tabs
          ValueListenableBuilder<List<PluginModel>>(
            valueListenable: pluginManager.pluginsNotifier,
            builder: (context, activePlugins, _) {
              final enabledPlugins = activePlugins.where((p) => p.enabled).toList();
              return _buildPillsBar(enabledPlugins);
            },
          ),
          const Divider(height: 1),

          // Contenido dinámico según la píldora/tab seleccionada
          Expanded(
            child: SingleChildScrollView(
              padding: commonSingleChildScrollViewPadding,
              child: _buildTabContent(playlistHeight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillsBar(List<PluginModel> plugins) {
    final pills = [
      {'id': 'offline', 'label': 'Offline', 'icon': FluentIcons.folder_24_regular},
      {'id': 'youtube', 'label': 'YouTube', 'icon': FluentIcons.play_24_regular},
      ...plugins.map((p) => {
            'id': p.id,
            'label': p.name,
            'icon': _getPluginIconData(p.type),
          }),
    ];

    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: pills.map((pill) {
            final isSelected = _selectedTabId == pill['id'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: isSelected,
                showCheckmark: false,
                avatar: Icon(
                  pill['icon'] as IconData,
                  size: 18,
                  color: isSelected ? Theme.of(context).colorScheme.onPrimary : null,
                ),
                label: Text(pill['label'] as String),
                selectedColor: Theme.of(context).colorScheme.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Theme.of(context).colorScheme.onPrimary : null,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedTabId = pill['id'] as String;
                    });
                    if (_selectedTabId != 'offline' && _selectedTabId != 'youtube') {
                      _loadPluginContent(_selectedTabId);
                    }
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
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

  Widget _buildTabContent(double playlistHeight) {
    if (_selectedTabId == 'offline') {
      return _buildOfflineContent();
    } else if (_selectedTabId == 'youtube') {
      return _buildYouTubeContent(playlistHeight);
    } else {
      return _buildPluginContent(_selectedTabId);
    }
  }

  Widget _buildOfflineContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<List>(
          valueListenable: userOfflineSongs,
          builder: (context, songs, _) {
            if (songs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(FluentIcons.music_note_2_24_regular, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        context.l10n!.noLocalFilesDescription,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => context.push('/settings'),
                        icon: const Icon(FluentIcons.settings_24_regular),
                        label: Text(context.l10n!.goToSettings),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${context.l10n!.localFiles} (${songs.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(FluentIcons.arrow_sync_24_regular),
                      onPressed: () {
                        final currentFolder = localMusicService.selectedFolderNotifier.value;
                        if (currentFolder.isNotEmpty) {
                          localMusicService.scanLocalMusicFolder(currentFolder);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...List.generate(songs.length, (index) {
                  final song = songs[index];
                  return SongBar(
                    song,
                    false,
                    onPlay: () {
                      audioHandler.playPlaylistSong(
                        playlist: {
                          'title': context.l10n!.localFiles,
                          'list': songs,
                        },
                        songIndex: index,
                      );
                    },
                  );
                }),
              ],
            );
          },
        ),
        const MiniPlayerBottomSpace(),
      ],
    );
  }

  Widget _buildYouTubeContent(double playlistHeight) {
    return Column(
      children: [
        ValueListenableBuilder<String?>(
          valueListenable: announcementURL,
          builder: (_, _url, __) {
            if (_url == null) return const SizedBox.shrink();
            final isSponsorshipAnnouncement = isSponsorshipAnnouncementUrl(_url);
            final _message = isSponsorshipAnnouncement
                ? context.l10n!.sponsorProject
                : context.l10n!.newAnnouncement;
            final _icon = isSponsorshipAnnouncement
                ? FluentIcons.heart_24_filled
                : FluentIcons.megaphone_24_filled;

            return AnnouncementBox(
              message: _message,
              url: _url,
              icon: _icon,
              onDismiss: () async {
                announcementURL.value = null;
              },
            );
          },
        ),
        _buildSuggestedPlaylists(playlistHeight),
        _buildSuggestedPlaylists(playlistHeight, showOnlyLiked: true),
        _buildCurrentMonthRecapSection(),
        _buildRecommendedSongsSection(),
        const MiniPlayerBottomSpace(),
      ],
    );
  }

  Widget _buildPluginContent(String pluginId) {
    final isLoading = _pluginLoadingState[pluginId] ?? false;
    final stations = _pluginStationsCache[pluginId] ?? [];

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (stations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            children: [
              const Icon(FluentIcons.plug_connected_24_regular, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                context.l10n!.noContentForPlugin,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  _pluginStationsCache.remove(pluginId);
                  _loadPluginContent(pluginId);
                },
                icon: const Icon(FluentIcons.arrow_sync_24_regular),
                label: Text(context.l10n!.loadOrReload),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${context.l10n!.stationsAndStreams} (${stations.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            IconButton(
              icon: const Icon(FluentIcons.arrow_sync_24_regular),
              onPressed: () {
                _pluginStationsCache.remove(pluginId);
                _loadPluginContent(pluginId);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(stations.length, (index) {
          final station = stations[index];
          return Padding(
            key: ValueKey(station.id),
            padding: const EdgeInsets.only(bottom: 8),
            child: RadioStationCard(
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
                  showToast(context, context.l10n!.error);
                }
              },
            ),
          );
        }),
        const MiniPlayerBottomSpace(),
      ],
    );
  }

  Widget _buildSuggestedPlaylists(
    double playlistHeight, {
    bool showOnlyLiked = false,
  }) {
    if (showOnlyLiked) {
      return ValueListenableBuilder<List<Map>>(
        valueListenable: userLikedPlaylists,
        builder: (_, likedPlaylists, __) => _buildSuggestedPlaylistsSection(
          playlistHeight,
          likedPlaylists
              .where((playlist) => !isArtistPlaylist(playlist))
              .take(recommendedCubesNumber)
              .toList(),
          showOnlyLiked: true,
        ),
      );
    }

    return AsyncLoader<List<dynamic>>(
      future: _suggestedPlaylistsFuture,
      builder: (context, playlists) =>
          _buildSuggestedPlaylistsSection(playlistHeight, playlists),
    );
  }

  Widget _buildSuggestedPlaylistsSection(
    double playlistHeight,
    List<dynamic> playlists, {
    bool showOnlyLiked = false,
  }) {
    if (playlists.isEmpty) return const SizedBox.shrink();

    final sectionTitle = showOnlyLiked
        ? context.l10n!.backToFavorites
        : context.l10n!.suggestedPlaylists;
    final itemsNumber = playlists.length.clamp(0, recommendedCubesNumber);
    final isLargeScreen = MediaQuery.of(context).size.width > 480;

    return Column(
      children: [
        SectionHeader(
          title: sectionTitle,
          icon: showOnlyLiked
              ? FluentIcons.heart_24_filled
              : FluentIcons.list_24_filled,
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: playlistHeight),
          child: isLargeScreen
              ? _buildHorizontalList(playlists, itemsNumber, playlistHeight)
              : _buildCarouselView(playlists, itemsNumber, playlistHeight),
        ),
      ],
    );
  }

  Widget _buildHorizontalList(
    List<dynamic> playlists,
    int itemCount,
    double height,
  ) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: GestureDetector(
            onTap: () => context.push('/home/playlist/${playlist['ytid']}'),
            child: PlaylistCube(playlist, size: height),
          ),
        );
      },
    );
  }

  Widget _buildCarouselView(
    List<dynamic> playlists,
    int itemCount,
    double height,
  ) {
    return CarouselView.weighted(
      flexWeights: const <int>[3, 2, 1],
      itemSnapping: true,
      onTap: (index) =>
          context.push('/home/playlist/${playlists[index]['ytid']}'),
      children: List.generate(itemCount, (index) {
        return PlaylistCube(playlists[index], size: height * 2);
      }),
    );
  }

  Widget _buildRecommendedSongsSection() {
    return AsyncLoader<List<dynamic>>(
      future: _recommendedSongsFuture,
      builder: (context, data) {
        if (data.isEmpty) return const SizedBox.shrink();
        return _buildRecommendedForYouSection(context, data);
      },
    );
  }

  Widget _buildCurrentMonthRecapSection() {
    return ValueListenableBuilder<bool>(
      valueListenable: wrappedEnabled,
      builder: (_, isEnabled, __) {
        if (!isEnabled) return const SizedBox.shrink();

        final currentMonthKey = listeningStatsMonthKey(DateTime.now());
        final monthStats = listeningStatsService.monthStats(currentMonthKey);
        final songs = listeningStatsService.monthTopSongs(currentMonthKey);
        final displayMinutes = monthDisplayMinutes(monthStats);
        if (displayMinutes <= 0 && songs.isEmpty) {
          return const SizedBox.shrink();
        }

        final previewSongs = songs.take(wrappedShareSongsLimit).toList();
        final periodLabel = formatMonthPeriodLabel(
          Localizations.localeOf(context),
          currentMonthKey,
        );

        return Column(
          children: [
            SectionHeader(
              title: context.l10n!.timeMachine,
              icon: FluentIcons.data_trending_24_filled,
            ),
            ListeningRecapCard(
              periodLabel: periodLabel,
              minutes: displayMinutes,
              songs: previewSongs,
              onSongTap: (index) => _playRecapSongs(previewSongs, index),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => context.push('/home/timeMachine'),
                  icon: const Icon(FluentIcons.arrow_right_24_regular),
                  label: Text(context.l10n!.listeningStats),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _playRecapSongs(
    List<Map<String, dynamic>> songs,
    int index,
  ) async {
    if (songs.isEmpty) return;
    await audioHandler.playPlaylistSong(
      playlist: {'title': context.l10n!.timeMachine, 'list': songs},
      songIndex: index,
    );
  }

  Widget _buildRecommendedForYouSection(
    BuildContext context,
    List<dynamic> data,
  ) {
    return RecommendedSongsSection(
      title: context.l10n!.recommendedForYou,
      songs: data,
      listKeyPrefix: 'home_recommended',
    );
  }
}
