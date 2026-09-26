import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// 内置配置源：打包进 App 的离线配置，不依赖 GitHub 域名。
/// 原始文件来自 GitHub qist/tvbox 仓库（0821.json / 9918.json）。
class BuiltinConfigs {
  static const all = [
    BuiltinConfig(
      name: '主流影视精选（推荐）',
      asset: 'assets/configs/mainstream.json',
      url: 'builtin://mainstream',
    ),
    BuiltinConfig(
      name: '影视聚合（9918）',
      asset: 'assets/configs/9918.json',
      url: 'builtin://9918',
    ),
    BuiltinConfig(
      name: '影视聚合（0821）',
      asset: 'assets/configs/0821.json',
      url: 'builtin://0821',
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
