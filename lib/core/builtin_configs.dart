/// 内置的公开配置源（来自 GitHub qist/tvbox 仓库，社区维护）。
class BuiltinConfigs {
  static const all = [
    BuiltinConfig(
      name: '影视聚合（0821）',
      url: 'https://raw.githubusercontent.com/qist/tvbox/master/0821.json',
    ),
    BuiltinConfig(
      name: '饭太硬',
      url: 'https://raw.githubusercontent.com/qist/tvbox/master/fty.json',
    ),
    BuiltinConfig(
      name: '影视聚合（9918）',
      url: 'https://raw.githubusercontent.com/qist/tvbox/master/9918.json',
    ),
    BuiltinConfig(
      name: '电视直播聚合',
      url: 'https://raw.githubusercontent.com/qist/tvbox/master/dianshi.json',
    ),
    BuiltinConfig(
      name: 'JS 大合集',
      url: 'https://raw.githubusercontent.com/qist/tvbox/master/js.json',
    ),
  ];
}

class BuiltinConfig {
  final String name;
  final String url;

  const BuiltinConfig({required this.name, required this.url});
}
