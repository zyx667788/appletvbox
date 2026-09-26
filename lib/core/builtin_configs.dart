import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// 内置配置源：打包进 App 的离线配置，不依赖外部配置下载。
class BuiltinConfigs {
  static const all = [
    BuiltinConfig(
      name: '主流影视精选（量子/暴风/非凡等14大资源站）',
      asset: 'assets/configs/mainstream.json',
      url: 'builtin://mainstream',
    ),
  ];

  static BuiltinConfig? byUrl(String url) {
    for (final c in all) {
      if (c.url == url) return c;
    }
    return null;
  }
}

class BuiltinConfig {
  final String name;
  final String asset;
  final String url;

  const BuiltinConfig({
    required this.name,
    required this.asset,
    required this.url,
  });

  /// 读取内置配置内容。
  Future<String> loadContent() => rootBundle.loadString(asset);

  Future<Map<String, dynamic>> loadJson() async {
    return jsonDecode(await loadContent()) as Map<String, dynamic>;
  }
}
