/**
 * Plugin: TuneIn Radio
 * ID: tunein
 * Type: radio
 * Translated from TestExtensionTUNE.kt
 */

const plugin = {
  id: 'tunein',
  name: 'TuneIn Radio',
  version: '1.0.0',
  type: 'radio',
  description: 'Búsqueda, categorías por país/género y reproducción TuneIn Radio (OPML API)',
  enabled: true,

  apiLink: 'https://opml.radiotime.com',
  initialUrl: 'https://opml.radiotime.com/Browse.ashx?c=local&render=json',

  getInitialUrl() {
    return 'https://opml.radiotime.com/Browse.ashx?c=local&render=json';
  },

  getSearchUrl(query) {
    return 'https://opml.radiotime.com/Search.ashx?query=' + encodeURIComponent(query) + '&render=json';
  },

  extractStationsFromItems(items, resultList) {
    if (!items || !Array.isArray(items)) return;
    for (var i = 0; i < items.length; i++) {
      var item = items[i];
      if (!item) continue;

      var streamUrl = item.URL || item.url || '';
      var title = item.text || item.title || '';

      if (title && streamUrl && (item.type === 'audio' || item.item === 'station' || streamUrl.includes('Tune.ashx') || streamUrl.includes('preset'))) {
        resultList.push({
          id: 'tunein:' + (item.guide_id || item.preset_id || item.text || i),
          title: title,
          artist: item.subtext || item.current_track || 'TuneIn Local Radio',
          image: item.image || '',
          streamUrl: streamUrl,
          type: 'radio'
        });
      }

      if (item.children && Array.isArray(item.children)) {
        this.extractStationsFromItems(item.children, resultList);
      }
    }
  },

  parseRadioStations(jsonText) {
    try {
      var data = JSON.parse(jsonText);
      var body = data.body || [];
      var results = [];
      this.extractStationsFromItems(body, results);
      return results;
    } catch (e) {
      return [];
    }
  },

  parseSearchResults(jsonText, query) {
    return this.parseRadioStations(jsonText);
  },

  getStreamUrl(rawUrl) {
    var url = rawUrl.replace('tunein:', '');
    return {
      url: url,
      headers: {
        'User-Agent': 'Musify/10.4.0'
      }
    };
  }
};
