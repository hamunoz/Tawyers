/**
 * Plugin: IPTV Audio Streams
 * ID: iptv_audio
 * Type: radio
 */

const plugin = {
  id: 'iptv_audio',
  name: 'IPTV Audio',
  version: '1.0.0',
  type: 'radio',
  description: 'Parser de listas IPTV (.m3u / .m3u8) con extracción de metadatos EXTINF, canales y streams HLS/TS/AAC',
  enabled: true,

  initialUrl: 'https://iptv-org.github.io/iptv/index.m3u',

  getInitialUrl() {
    return 'https://iptv-org.github.io/iptv/index.m3u';
  },

  getSearchUrl(query) {
    return 'https://iptv-org.github.io/iptv/index.m3u';
  },

  parseExtInf(headerLine) {
    var meta = {
      title: 'Canal IPTV',
      logo: '',
      group: 'IPTV Audio',
      tvgId: ''
    };

    try {
      var logoMatch = headerLine.match(/tvg-logo="([^"]+)"/i);
      if (logoMatch) meta.logo = logoMatch[1];

      var groupMatch = headerLine.match(/group-title="([^"]+)"/i);
      if (groupMatch) meta.group = groupMatch[1];

      var idMatch = headerLine.match(/tvg-id="([^"]+)"/i);
      if (idMatch) meta.tvgId = idMatch[1];

      var commaIndex = headerLine.lastIndexOf(',');
      if (commaIndex !== -1) {
        var titleStr = headerLine.substring(commaIndex + 1).trim();
        if (titleStr.length > 0) meta.title = titleStr;
      }
    } catch (e) {}

    return meta;
  },

  parseHeadersFromUrl(url) {
    var headers = {
      'User-Agent': 'VLC/3.0.18 LibVLC/3.0.18'
    };

    var cleanUrl = url;
    if (url.includes('|')) {
      var parts = url.split('|');
      cleanUrl = parts[0].trim();
      var params = parts[1].split('&');
      for (var i = 0; i < params.length; i++) {
        var kv = params[i].split('=');
        if (kv.length === 2) {
          headers[decodeURIComponent(kv[0])] = decodeURIComponent(kv[1]);
        }
      }
    }

    return { url: cleanUrl, headers: headers };
  },

  parseRadioStations(m3uText) {
    var channels = [];
    var lines = m3uText.split('\n');

    var currentMeta = null;
    var customHeaders = { 'User-Agent': 'VLC/3.0.18 LibVLC/3.0.18' };
    var maxChannels = 100; // Límite inicial de canales para garantizar máxima fluidez

    for (var i = 0; i < lines.length && channels.length < maxChannels; i++) {
      var line = lines[i].trim();
      if (!line) continue;

      if (line.startsWith('#EXTINF:')) {
        currentMeta = this.parseExtInf(line);
      } else if (line.startsWith('#EXTVLCOPT:http-user-agent=')) {
        customHeaders['User-Agent'] = line.substring(27).trim();
      } else if (line.startsWith('#EXTHTTP:')) {
        try {
          var jsonStr = line.substring(9).trim();
          var parsedHeaders = JSON.parse(jsonStr);
          Object.assign(customHeaders, parsedHeaders);
        } catch (e) {}
      } else if (!line.startsWith('#')) {
        var streamInfo = this.parseHeadersFromUrl(line);
        var finalMeta = currentMeta || {
          title: 'Canal ' + (channels.length + 1),
          logo: '',
          group: 'IPTV Audio',
          tvgId: ''
        };

        channels.push({
          id: 'iptv_audio:' + channels.length + '_' + (finalMeta.tvgId || 'ch'),
          title: finalMeta.title,
          artist: finalMeta.group || 'IPTV Stream',
          image: finalMeta.logo || '',
          streamUrl: streamInfo.url,
          headers: Object.assign({}, customHeaders, streamInfo.headers),
          type: 'radio'
        });

        currentMeta = null;
        customHeaders = { 'User-Agent': 'VLC/3.0.18 LibVLC/3.0.18' };
      }
    }

    return channels;
  },

  parseSearchResults(m3uText, query) {
    var all = this.parseRadioStations(m3uText);
    if (!query || query.trim().length === 0) return all;

    var lower = query.toLowerCase();
    return all.filter(function(c) {
      return c.title.toLowerCase().includes(lower) || c.artist.toLowerCase().includes(lower);
    });
  },

  getStreamUrl(streamUrl) {
    var rawUrl = streamUrl.replace('iptv_audio:', '').replace('iptv:', '');
    var streamInfo = this.parseHeadersFromUrl(rawUrl);

    return {
      url: streamInfo.url,
      headers: streamInfo.headers
    };
  }
};
