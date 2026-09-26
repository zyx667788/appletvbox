import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/json_vod_client.dart';
import '../../core/live_parser.dart';
import '../player/player_page.dart';

class LivePage extends StatefulWidget {
  const LivePage({super.key});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  List<LiveChannel> _allChannels = [];
  List<String> _groups = [];
  String _selectedGroup = '全部';
  String _searchQuery = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    try {
      final content = await rootBundle.loadString('assets/live/channels.m3u');
      final list = M3uParser.parse(content);
      final groupSet = <String>{};
      for (final c in list) {
        if (c.group.isNotEmpty) groupSet.add(c.group);
      }
      if (mounted) {
        setState(() {
          _allChannels = list;
          _groups = ['全部', ...groupSet];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<LiveChannel> get _filteredChannels {
    return _allChannels.where((c) {
      final matchGroup =
          _selectedGroup == '全部' || c.group == _selectedGroup;
      final matchQuery = _searchQuery.isEmpty ||
          c.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchGroup && matchQuery;
    }).toList();
  }

  void _playChannel(LiveChannel channel) {
    final channels = _filteredChannels;
    final initialIndex = channels.indexOf(channel);
    // 将频道列表打包成播放集数，支持在直播播放器内按上一台/下一台换台
    final episodes = channels
        .map((c) => Episode(name: c.name, url: c.url))
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerPage(
          title: '电视直播 · ${channel.group}',
          url: channel.url,
          episodes: episodes,
          initialIndex: initialIndex >= 0 ? initialIndex : 0,
          initialIsFullscreen: true, // 直播点击默认直接进全屏横屏！
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('电视直播'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索电视频道（如 CCTV、卫视）',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFF242424),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (q) => setState(() => _searchQuery = q.trim()),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 顶部分组选择栏（横向滚动）
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _groups.length,
                    itemBuilder: (context, idx) {
                      final g = _groups[idx];
                      final isSelected = g == _selectedGroup;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
                        child: ChoiceChip(
                          label: Text(g),
                          selected: isSelected,
                          onSelected: (_) =>
                              setState(() => _selectedGroup = g),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                // 频道列表
                Expanded(
                  child: _filteredChannels.isEmpty
                      ? const Center(child: Text('没有找到相关电视频道'))
                      : ListView.separated(
                          itemCount: _filteredChannels.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, indent: 64),
                          itemBuilder: (context, idx) {
                            final c = _filteredChannels[idx];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF2A2A2A),
                                child: const Icon(Icons.tv,
                                    color: Colors.white70, size: 20),
                              ),
                              title: Text(c.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500)),
                              subtitle: Text(c.group,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.white54)),
                              trailing: const Icon(Icons.play_arrow,
                                  color: Colors.redAccent, size: 22),
                              onTap: () => _playChannel(c),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
