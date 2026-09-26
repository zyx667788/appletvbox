import 'dart:convert';

import 'package:http/http.dart' as http;

import 'http_client_factory.dart';

import '../models/tvbox_config.dart';

/// 拉取并解析 TVBox config JSON。
Future<TvboxConfig> loadTvboxConfig(String url, {http.Client? client}) async {
  final c = client ?? createHttpClient();
  try {
    final res = await c.get(
      Uri.parse(url),
      headers: {'User-Agent': 'okhttp/3.15'},
    );
    if (res.statusCode != 200) {
      throw Exception('配置源请求失败：HTTP ${res.statusCode}');
    }
    final body = res.body.trim();
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('配置不是合法的 TVBox JSON');
    }
    return TvboxConfig.fromJson(decoded, baseUrl: url);
  } finally {
    if (client == null) c.close();
  }
}
