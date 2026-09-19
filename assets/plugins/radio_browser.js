/**
 * Plugin: Radio Browser
 * ID: radio_browser
 * Type: radio
 */

const plugin = {
  id: 'radio_browser',
  name: 'Radio Browser',
  version: '1.0.0',
  type: 'radio',
  description: 'Directorio público global con más de 30,000 estaciones de radio por internet organizadas por país y género',
  enabled: true,

  initialUrl: 'https://de1.api.radio-browser.info/json/stations/topclick/30',

  getInitialUrl() {
    return 'https://de1.api.radio-browser.info/json/stations/topclick/30';
  },

  getSearchUrl(query) {
    return 'https://de1.api.radio-browser.info/json/stations/byname/' + encodeURIComponent(query) + '?limit=25';
  },

  parseRadioStations(jsonText) {
    try {
      var data = JSON.parse(jsonText);
      if (!Array.isArray(data)) return [];

      var results = [];
      for (var i = 0; i < data.length; i++) {
        var s = data[i];
        if (!s || (!s.url_resolved && !s.url)) continue;

        results.push({
          id: 'radio_browser:' + (s.stationuuid || i),
          title: s.name || 'Radio Browser',
          artist: s.country ? (s.country + ' • ' + (s.tags || '')) : (s.tags || 'Internet Radio'),
          image: s.favicon || '',
          streamUrl: s.url_resolved || s.url,
          genre: s.tags,
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
    var url = rawUrl.replace('radio_browser:', '').replace('rb:', '');
    return {
      url: url,
      headers: {
        'User-Agent': 'Musify/10.4.0'
      }
    };
  }
};
