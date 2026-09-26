import 'package:flutter/material.dart';

import '../../core/json_vod_client.dart';
import '../../models/tvbox_config.dart';
import '../player/player_page.dart';
import '../detail/detail_page.dart';

class SearchPage extends StatefulWidget {
  final TvboxConfig config;

  const SearchPage({super.key, required this.config});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  bool _searching = false;
  final Map<String, List<VodItem>> _results = {};
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;
    setState(() {
      _searching = true;
      _results.clear();
      _error = null;
    });
    final sites = widget.config.sites
        .where((s) => s.supported && s.type == SiteType.json)
        .take(12)
        .toList();
    try {
      await Future.wait(sites.map((site) async {
        final client = JsonVodClient(site.api);
        try {
          final items = await client.search(keyword);
          if (items.isNotEmpty && mounted) {
            setState(() {
              _results[site.name] = items;
            });
          }
        } catch (_) {
          // 单个源失败不阻塞整体搜索
        } finally {
          client.close();
        }
      }));
      if (_results.isEmpty && mounted) _error = '没有找到结果';
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: '输入影片名',
                suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _search),
              ),
            ),
          ),
          if (_searching) const LinearProgressIndicator(),
          if (_error != null) Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
          Expanded(
            child: ListView(
              children: _results.entries
                  .map((entry) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(entry.key, style: Theme.of(context).textTheme.titleMedium),
                          ),
                          ...entry.value.map((item) => ListTile(
                                leading: item.pic != null && item.pic!.isNotEmpty
                                    ? Image.network(item.pic!, width: 48, errorBuilder: (_, _, _) => const Icon(Icons.movie))
                                    : const Icon(Icons.movie),
                                title: Text(item.name),
                                subtitle: Text(item.note ?? ''),
                                onTap: () => _openDetail(entry.key, item),
                              )),
                        ],
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _openDetail(String siteName, VodItem item) {
    final site = widget.config.sites.firstWhere(
      (s) => s.name == siteName,
      orElse: () => widget.config.sites.first,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailLoaderPage(site: site, item: item),
      ),
    );
  }
}

/// 搜索结果进入详情的包装页：先取完整详情再渲染。
class DetailLoaderPage extends StatefulWidget {
  final Site site;
  final VodItem item;

  const DetailLoaderPage({super.key, required this.site, required this.item});

  @override
  State<DetailLoaderPage> createState() => _DetailLoaderPageState();
}

class _DetailLoaderPageState extends State<DetailLoaderPage> {
  late final Future<VodItem> _future;

  @override
  void initState() {
    super.initState();
    final client = JsonVodClient(widget.site.api);
    _future = client.detail('${widget.item.id}').then((list) {
      client.close();
      return list.isEmpty ? widget.item : list.first;
    }).catchError((_) {
      client.close();
      return widget.item;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<VodItem>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.item.name)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final item = snap.data ?? widget.item;
        final client = JsonVodClient(widget.site.api);
        return DetailPage(
          site: widget.site,
          client: client,
          item: item,
          onPlay: (episode, allGroups, {resumeSeconds, groupIndex}) {
            final validGIdx = (groupIndex != null && groupIndex >= 0 && groupIndex < allGroups.length)
                ? groupIndex
                : allGroups.indexWhere((g) => g.episodes.contains(episode)).clamp(0, allGroups.isNotEmpty ? allGroups.length - 1 : 0);
            final epList = allGroups.isNotEmpty ? allGroups[validGIdx].episodes : [episode];
            final epIdx = epList.indexOf(episode);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlayerPage(
                  title: item.name,
                  url: episode.url,
                  groups: allGroups,
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
        );
      },
    );
  }
}
