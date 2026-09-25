/// TVBox 生态站点类型。一期支持 csp_XBPQ / csp_XYQ / JSON 直出，
/// jar 爬虫在 iOS 上无法运行，标记为不支持。
enum SiteType { json, xbpq, xyq, js, jar, unknown }

class SiteTypeHelper {
  static SiteType parse(String? api) {
    if (api == null) return SiteType.unknown;
    final lower = api.toLowerCase();
    if (lower.startsWith('csp_xbpq')) return SiteType.xbpq;
    if (lower.startsWith('csp_xyq')) return SiteType.xyq;
    if (lower.startsWith('csp_')) {
      if (lower.contains('jar') || lower.contains('.jar')) return SiteType.jar;
      return SiteType.js;
    }
    if (lower.endsWith('.json') || lower.contains('provide/vod')) {
      return SiteType.json;
    }
    return SiteType.unknown;
  }

  static String describe(SiteType type) {
    switch (type) {
      case SiteType.json:
        return 'JSON 直出';
      case SiteType.xbpq:
        return 'XBPQ';
      case SiteType.xyq:
        return 'XYQ';
      case SiteType.js:
        return 'JS';
      case SiteType.jar:
        return '不支持（jar 爬虫）';
      case SiteType.unknown:
        return '未知';
    }
  }
}

class Site {
  final String key;
  final String name;
  final String api;
  final SiteType type;
  final String? searchable;
  final String? quickSearch;

  Site({
    required this.key,
    required this.name,
    required this.api,
    required this.type,
    this.searchable,
    this.quickSearch,
  });

  bool get supported => type != SiteType.jar && type != SiteType.unknown;

  factory Site.fromJson(Map<String, dynamic> json) {
    final api = (json['api'] ?? json['url'] ?? '').toString();
    final jar = json['jar']?.toString();
    return Site(
      key: (json['key'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      api: api,
      type: jar != null && jar.isNotEmpty ? SiteType.jar : SiteTypeHelper.parse(api),
      searchable: json['searchable']?.toString(),
      quickSearch: json['quickSearch']?.toString(),
    );
  }
}

class LiveGroup {
  final String name;
  final String url;

  LiveGroup({required this.name, required this.url});
}

class TvboxConfig {
  final String? spider;
  final List<Site> sites;
  final List<LiveGroup> lives;
  final List<String> parses;

  TvboxConfig({
    this.spider,
    required this.sites,
    required this.lives,
    required this.parses,
  });

  factory TvboxConfig.fromJson(
    Map<String, dynamic> json, {
    String baseUrl = '',
  }) {
    final sites = <Site>[];
    final rawSites = json['sites'];
    if (rawSites is List) {
      for (final s in rawSites) {
        if (s is Map<String, dynamic>) sites.add(Site.fromJson(s));
      }
    }

    final lives = <LiveGroup>[];
    final rawLives = json['lives'];
    if (rawLives is List) {
      for (final group in rawLives) {
        if (group is Map<String, dynamic>) {
          final groupName = (group['name'] ?? '直播').toString();
          final groupItems = group['channels'] ?? group['list'];
          if (groupItems is List) {
            for (final item in groupItems) {
              if (item is Map<String, dynamic>) {
                lives.add(LiveGroup(
                  name: (item['name'] ?? groupName).toString(),
                  url: (item['urls'] ?? item['url'] ?? '').toString(),
                ));
              }
            }
          }
        } else if (group is String) {
          lives.add(LiveGroup(name: '直播', url: group));
        }
      }
    }

    final parses = <String>[];
    final rawParses = json['parses'];
    if (rawParses is List) {
      for (final p in rawParses) {
        if (p is Map<String, dynamic>) {
          final u = p['url'];
          if (u != null) parses.add(u.toString());
        }
      }
    }

    return TvboxConfig(
      spider: json['spider']?.toString(),
      sites: sites,
      lives: lives,
      parses: parses,
    );
  }
}
