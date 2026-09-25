import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

/// 极简 m3u 直播源解析（EXTM3U）。
class M3uParser {
  static List<LiveChannel> parse(String content) {
    final channels = <LiveChannel>[];
    String? pendingName;
    String? pendingGroup;
    for (final rawLine in const LineSplitter().convert(content)) {
      final line = rawLine.trim();
      if (line.startsWith('#EXTINF')) {
        final commaIdx = line.lastIndexOf(',');
        pendingName = commaIdx >= 0 ? line.substring(commaIdx + 1).trim() : '';
        final groupMatch = RegExp(r'group-title="([^"]*)"').firstMatch(line);
        pendingGroup = groupMatch?.group(1) ?? pendingGroup;
      } else if (line.isNotEmpty && !line.startsWith('#')) {
        channels.add(LiveChannel(
          name: pendingName ?? '',
          url: line,
          group: pendingGroup ?? '未分组',
        ));
        pendingName = null;
      }
    }
    return channels;
  }

  static Future<List<LiveChannel>> load(String url, {http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final res = await c.get(Uri.parse(url));
      if (res.statusCode != 200) {
        throw Exception('直播源请求失败：HTTP ${res.statusCode}');
      }
      return parse(utf8.decode(res.bodyBytes));
    } finally {
      if (client == null) c.close();
    }
  }
}

/// 把直播 txt（“分组,#genre#” + “频道名,url” 行）转成频道列表。
List<LiveChannel> parseLiveTxt(String content) {
  final channels = <LiveChannel>[];
  var group = '未分组';
  for (final rawLine in const LineSplitter().convert(content)) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    final parts = line.split(',');
    if (parts.length >= 2 && parts[1].trim() == '#genre#') {
      group = parts[0].trim();
      continue;
    }
    if (parts.length >= 2 && Uri.tryParse(parts[1].trim())?.hasScheme == true) {
      channels.add(LiveChannel(
        name: parts[0].trim(),
        url: parts[1].trim(),
        group: group,
      ));
    }
  }
  return channels;
}

class LiveChannel {
  final String name;
  final String url;
  final String group;

  LiveChannel({required this.name, required this.url, required this.group});
}

/// 兜底 HTML 标题抽取，用于后续 XBPQ/XYQ 源扩展。
String? extractTitle(String html) {
  final doc = html_parser.parse(html);
  return doc.querySelector('title')?.text.trim();
}
