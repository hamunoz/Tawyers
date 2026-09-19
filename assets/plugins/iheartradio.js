/**
 * Plugin: iHeartRadio
 * ID: iheartradio
 * Type: radio
 */

const plugin = {
  id: 'iheartradio',
  name: 'iHeartRadio',
  version: '1.0.0',
  type: 'radio',
  description: 'Búsqueda, géneros y reproducción de emisoras iHeartRadio (HLS, Shoutcast, PLS)',
  enabled: true,

  initialUrl: 'https://api.iheart.com/api/v2/content/liveStations?limit=30',

  getInitialUrl() {
    return 'https://api.iheart.com/api/v2/content/liveStations?limit=30';
  },

  getSearchUrl(query) {
    return 'https://api.iheart.com/api/v1/catalog/searchAll?keywords=' + encodeURIComponent(query) + '&maxRows=20';
  },

  extractBestStream(streams) {
    if (!streams) return null;
    if (streams.secure_hls_stream && streams.secure_hls_stream.length > 0) {
      return streams.secure_hls_stream;
    }
    if (streams.secure_shoutcast_stream && streams.secure_shoutcast_stream.length > 0) {
      return streams.secure_shoutcast_stream;
    }
    if (streams.secure_pls_stream && streams.secure_pls_stream.length > 0) {
      return streams.secure_pls_stream;
    }
    return null;
  },

  parseRadioStations(jsonText) {
    try {
      var data = JSON.parse(jsonText);
      var hits = data.hits || data.stations || [];
      var results = [];

      for (var i = 0; i < hits.length; i++) {
        var item = hits[i];
        if (!item) continue;

        var streamUrl = this.extractBestStream(item.streams);
        if (!streamUrl && item.streamUrl) streamUrl = item.streamUrl;
        if (!streamUrl) continue;

        results.push({
          id: 'iheartradio:' + (item.id || i),
          title: item.name || item.callLetters || 'Emisora iHeartRadio',
          artist: item.description || 'iHeartRadio Live',
          image: item.logo || '',
          streamUrl: streamUrl,
          genre: 'Radio Live',
          type: 'radio'
        });
      }

      return results;
    } catch (e) {
      return [];
    }
  },

  parseSearchResults(jsonText, query) {
    return this.parseRadioStations(jsonText);
  },

  getStreamUrl(rawUrl) {
    var url = rawUrl.replace('iheartradio:', '').replace('iheart:', '');
    return {
      url: url,
      headers: {
        'User-Agent': 'Musify/10.4.0'
      }
    };
  }
};
