import 'package:flutter/material.dart';

import '../../core/builtin_configs.dart';
import '../../core/config_loader.dart';
import '../../core/json_vod_client.dart';
import '../../data/app_store.dart';
import '../../models/tvbox_config.dart';
import '../detail/detail_page.dart';
import '../player/player_page.dart';
import '../search/search_page.dart';

/// 首页：加载配置源，展示可用站点与最近搜索结果入口。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _store = AppStore();
  TvboxConfig? _config;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var url = await _store.getConfigUrl();
    if (url == null || url.isEmpty) {
      url = 'builtin://mainstream';
      await _store.setConfigUrl(url);
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final config = await _loadConfig(url);
      setState(() => _config = config);
    } catch (e) {
      setState(() => _error = '加载失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 内置源（builtin://）直接读打包的配置文件，其它走网络。
  Future<TvboxConfig> _loadConfig(String url) async {
    final builtin = BuiltinConfigs.byUrl(url);
    if (builtin != null) {
      return TvboxConfig.fromJson(await builtin.loadJson());
    }
    return loadTvboxConfig(url);
  }

  @override
  Widget build(BuildContext context) {
    final sites = _config?.sites.where((s) => s.supported).toList() ?? const <Site>[];
    final unsupported = _config?.sites.where((s) => !s.supported).length ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('TVBox'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _config == null
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SearchPage(config: _config!)),
                    ),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : sites.isEmpty
                  ? const Center(child: Text('配置里没有可用站点'))
                  : ListView(
                      children: [
                        if (unsupported > 0)
                          ListTile(
                            leading: const Icon(Icons.info_outline),
                            title: Text('有 $unsupported 个 jar/未知源暂不支持，已隐藏'),
                          ),
                        ...sites.map((site) => ListTile(
                              leading: const Icon(Icons.movie),
                              title: Text(site.name),
                              subtitle: Text(SiteTypeHelper.describe(site.type)),
                              onTap: () => _openSite(context, site),
                            )),
                      ],
                    ),
    );
  }

  void _openSite(BuildContext context, Site site) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SiteBrowsePage(site: site),
      ),
    );
  }
}

/// 站点浏览页：展示分类与影片列表，支持分页。
class SiteBrowsePage extends StatefulWidget {
  final Site site;

  const SiteBrowsePage({super.key, required this.site});

  @override
  State<SiteBrowsePage> createState() => _SiteBrowsePageState();
}

class _SiteBrowsePageState extends State<SiteBrowsePage> {
  late final JsonVodClient _client;
  final _store = AppStore();
  List<VodItem> _items = [];
  List<VodType> _types = [];
  bool _loading = false;
  int _page = 1;
  bool _hasMore = true;
  String _currentTid = '';

  @override
  void initState() {
    super.initState();
    _client = JsonVodClient(widget.site.api);
    _load();
    _loadTypes();
  }

  Future<void> _loadTypes() async {
    final types = await _client.fetchTypes();
    if (mounted && types.isNotEmpty) {
      setState(() => _types = types);
    }
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    final page = reset ? 1 : _page;
    try {
      final items = await _client.category(
        tid: _currentTid.isEmpty ? null : _currentTid,
        page: page,
      );
      setState(() {
        if (reset) {
          _items = items;
        } else {
          _items.addAll(items);
        }
        _hasMore = items.length >= 20;
        _page = page + 1;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.site.name)),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('全部'),
                    selected: _currentTid.isEmpty,
                    onSelected: (_) {
                      if (_currentTid.isEmpty) return;
                      setState(() => _currentTid = '');
                      _load(reset: true);
                    },
                  ),
                ),
                ..._types.map((t) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(t.name),
                        selected: _currentTid == t.id,
                        onSelected: (_) {
                          if (_currentTid == t.id) return;
                          setState(() => _currentTid = t.id);
                          _load(reset: true);
                        },
                      ),
                    )),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.55,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _items.length + (_hasMore ? 1 : 0),
              itemBuilder: (_, i) {
                if (i >= _items.length) {
                  _load();
                  return const Center(child: CircularProgressIndicator());
                }
                final item = _items[i];
                return VodCard(
                  item: item,
                  onTap: () => _openDetail(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(VodItem item) async {
    final detail = await _client.detail('${item.id}');
    if (!mounted || detail.isEmpty) return;
    await _store.addHistory(HistoryEntry(
      siteKey: widget.site.key,
      siteName: widget.site.name,
      vodId: item.id,
      vodName: item.name,
      pic: item.pic,
      note: item.note,
      watchedAt: DateTime.now().millisecondsSinceEpoch,
    ));
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailPage(
          site: widget.site,
          client: _client,
          item: detail.first,
          onPlay: (episode, groups, {resumeSeconds, groupIndex}) {
            final validGIdx = (groupIndex != null && groupIndex >= 0 && groupIndex < groups.length)
                ? groupIndex
                : groups.indexWhere((g) => g.episodes.contains(episode)).clamp(0, groups.isNotEmpty ? groups.length - 1 : 0);
            final epList = groups.isNotEmpty ? groups[validGIdx].episodes : [episode];
            final epIdx = epList.indexOf(episode);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlayerPage(
                  title: item.name,
                  url: episode.url,
                  groups: groups,
                  initialGroupIndex: validGIdx,
                  initialIndex: epIdx >= 0 ? epIdx : 0,
                  episodes: epList,
                  siteKey: widget.site.key,
                  siteName: widget.site.name,
                  vodId: item.id,
                  vodName: item.name,
                  vodPic: item.pic,
                  vodNote: item.note,
                  initialPositionSeconds: resumeSeconds,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class VodCard extends StatelessWidget {
  final VodItem item;
  final VoidCallback onTap;

  const VodCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: item.pic == null || item.pic!.isEmpty
                ? Container(
                    color: Colors.grey[850],
                    child: const Center(child: Icon(Icons.movie)),
                  )
                : Image.network(item.pic!, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: Colors.grey[850], child: const Icon(Icons.error_outline))),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (item.note != null)
            Text(item.note!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
