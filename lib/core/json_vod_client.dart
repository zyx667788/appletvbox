import 'dart:convert';

import 'package:http/http.dart' as http;

import 'http_client_factory.dart';

/// 把配置里的 api 地址归一化成可用的接口基址。
/// 兼容 .../provide/vod/ 、...?ac=list 、.../at/xml/ 等写法。
String normalizeApiBase(String raw) {
  final qIdx = raw.indexOf('?');
  var base = qIdx >= 0 ? raw.substring(0, qIdx) : raw;
  final idx = base.indexOf('provide/vod');
  if (idx >= 0) return base.substring(0, idx + 'provide/vod'.length);
  return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
}

/// JSON 直出源（MacCMS10 / provide/vod 风格）客户端。
class JsonVodClient {
  final String baseUrl;
  final http.Client _client;

  JsonVodClient(String rawBaseUrl, {http.Client? client})
      : baseUrl = normalizeApiBase(rawBaseUrl),
        _client = client ?? createHttpClient();

  Future<Map<String, dynamic>> _get([Map<String, String>? query]) async {
    final parts = <String>[];
    query?.forEach((k, v) {
      parts.add('$k=${Uri.encodeQueryComponent(v)}');
    });
    final uri =
        Uri.parse(parts.isEmpty ? baseUrl : '$baseUrl?${parts.join('&')}');
    final res = await _client.get(uri, headers: {'User-Agent': 'okhttp/3.15'});
    if (res.statusCode != 200) {
      throw Exception('源请求失败：HTTP ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// 获取站点真实的一级/二级分类列表
  Future<List<VodType>> fetchTypes() async {
    try {
      final data = await _get({'ac': 'list'});
      final rawClass = data['class'];
      if (rawClass is List) {
        return rawClass
            .whereType<Map>()
            .map((e) => VodType(
                  id: (e['type_id'] ?? '').toString(),
                  name: (e['type_name'] ?? '').toString(),
                ))
            .where((t) => t.id.isNotEmpty && t.name.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// 按分类分页拉取影片，如果不传 tid 则拉取最新全部影片
  Future<List<VodItem>> category({String? tid, int page = 1}) async {
    final query = <String, String>{'ac': 'videolist', 'pg': '$page'};
    if (tid != null && tid.isNotEmpty) {
      query['t'] = tid;
    }
    final data = await _get(query);
    return _parseList(data);
  }

  Future<List<VodItem>> search(String keyword) async {
    final data = await _get({'ac': 'videolist', 'wd': keyword});
    return _parseList(data);
  }

  Future<List<VodItem>> detail(String ids) async {
    final data = await _get({'ac': 'videolist', 'ids': ids});
    return _parseList(data);
  }

  List<VodItem> _parseList(Map<String, dynamic> data) {
    final list = data['list'];
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => VodItem.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  void close() => _client.close();
}

class VodType {
  final String id;
  final String name;

  const VodType({required this.id, required this.name});
}

class VodItem {
  final int id;
  final String name;
  final String? type;
  final String? pic;
  final String? note;
  final String? actor;
  final String? director;
  final String? descr;
  final String? playFrom;
  final String? playUrl;

  VodItem({
    required this.id,
    required this.name,
    this.type,
    this.pic,
    this.note,
    this.actor,
    this.director,
    this.descr,
    this.playFrom,
    this.playUrl,
  });

  /// 把 vod_play_url（集名$链接#集名$链接，多线路用 $$$ 分隔）拆成播放组。
  List<PlayGroup> get playGroups {
    final raw = playUrl ?? '';
    final groups = <PlayGroup>[];
    final names = (playFrom ?? '').split(r'$$$');
    final rawGroups = raw.split(r'$$$');
    for (var i = 0; i < rawGroups.length; i++) {
      final episodes = <Episode>[];
      for (final pair in rawGroups[i].split('#')) {
        if (pair.isEmpty) continue;
        final parts = pair.split(r'$');
        if (parts.length < 2) continue;
        episodes.add(Episode(
          name: parts[0],
          url: parts.sublist(1).join(r'$'),
        ));
      }
      if (episodes.isNotEmpty) {
        groups.add(PlayGroup(
          name:
              i < names.length && names[i].isNotEmpty ? names[i] : '播放源${i + 1}',
          episodes: episodes,
        ));
      }
    }
    return groups;
  }

  factory VodItem.fromJson(Map<String, dynamic> json) => VodItem(
        id: int.tryParse(json['vod_id']?.toString() ?? '') ?? 0,
        name: json['vod_name']?.toString() ?? '',
        type: json['type_name']?.toString(),
        pic: json['vod_pic']?.toString(),
        note: json['vod_remarks']?.toString(),
        actor: json['vod_actor']?.toString(),
        director: json['vod_director']?.toString(),
        descr: json['vod_content']?.toString(),
        playFrom: json['vod_play_from']?.toString(),
        playUrl: json['vod_play_url']?.toString(),
      );
}

class PlayGroup {
  final String name;
  final List<Episode> episodes;

  PlayGroup({required this.name, required this.episodes});
}

class Episode {
  final String name;
  final String url;

  Episode({required this.name, required this.url});
}
