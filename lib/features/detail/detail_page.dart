import 'package:flutter/material.dart';

import '../../core/json_vod_client.dart';
import '../../data/app_store.dart';
import '../../models/tvbox_config.dart';

typedef PlayCallback = void Function(
  Episode episode,
  List<PlayGroup> groups, {
  int? resumeSeconds,
  int? groupIndex,
});

class DetailPage extends StatefulWidget {
  final Site site;
  final JsonVodClient client;
  final VodItem item;
  final PlayCallback onPlay;

  const DetailPage({
    super.key,
    required this.site,
    required this.client,
    required this.item,
    required this.onPlay,
  });

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final _store = AppStore();
  late bool _isFavorite;
  bool _favoriteLoaded = false;
  HistoryEntry? _history;

  @override
  void initState() {
    super.initState();
    _isFavorite = false;
    _store.isFavorite(widget.site.key, widget.item.id).then((v) {
      if (mounted) {
        setState(() {
          _isFavorite = v;
          _favoriteLoaded = true;
        });
      }
    });
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final h = await _store.getHistoryFor(widget.site.key, widget.item.id);
    if (mounted && h != null) {
      setState(() => _history = h);
    }
  }

  Future<void> _toggleFavorite() async {
    await _store.toggleFavorite(FavoriteEntry(
      siteKey: widget.site.key,
      siteName: widget.site.name,
      vodId: widget.item.id,
      vodName: widget.item.name,
      pic: widget.item.pic,
      note: widget.item.note,
    ));
    if (!mounted) return;
    setState(() => _isFavorite = !_isFavorite);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$m:$s';
    }
    return '$m:$s';
  }

  void _resumeHistory(List<PlayGroup> groups) {
    if (_history == null || groups.isEmpty) return;
    var gIdx = _history!.lastGroupIndex;
    if (gIdx < 0 || gIdx >= groups.length) gIdx = 0;
    final episodes = groups[gIdx].episodes;
    if (episodes.isEmpty) return;
    var epIdx = _history!.lastEpisodeIndex;
    if (epIdx < 0 || epIdx >= episodes.length) epIdx = 0;

    widget.onPlay(
      episodes[epIdx],
      groups,
      resumeSeconds: _history!.lastPositionSeconds,
      groupIndex: gIdx,
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.item.playGroups;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item.name),
        actions: [
          if (_favoriteLoaded)
            IconButton(
              icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
              onPressed: _toggleFavorite,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.item.pic != null && widget.item.pic!.isNotEmpty)
                SizedBox(
                  width: 110,
                  height: 155,
                  child: Image.network(
                    widget.item.pic!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Container(color: Colors.grey[850]),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.item.name,
                        style: Theme.of(context).textTheme.titleLarge),
                    if (widget.item.type != null)
                      Text('类型：${widget.item.type}'),
                    if (widget.item.note != null)
                      Text('备注：${widget.item.note}'),
                    if (widget.item.actor != null &&
                        widget.item.actor!.isNotEmpty)
                      Text('演员：${widget.item.actor}',
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                    if (widget.item.director != null &&
                        widget.item.director!.isNotEmpty)
                      Text('导演：${widget.item.director}'),
                  ],
                ),
              ),
            ],
          ),
          if (widget.item.descr != null &&
              widget.item.descr!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(widget.item.descr!.replaceAll(RegExp(r'<[^>]+>'), ''),
                maxLines: 6, overflow: TextOverflow.ellipsis),
          ],
          // 历史断点续播提示横条
          if (_history != null && _history!.lastPositionSeconds > 5) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 20, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '上次播放到：${_history!.lastEpisodeName ?? "第${_history!.lastEpisodeIndex + 1}集"} '
                      '${_formatDuration(Duration(seconds: _history!.lastPositionSeconds))}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13),
                    ),
                  ),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onPressed: () => _resumeHistory(groups),
                    child: const Text('继续播放'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          // 播放源/线路与各集
          ...groups.asMap().entries.map((entry) {
            final gIdx = entry.key;
            final group = entry.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(group.name,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: group.episodes.asMap().entries.map((epEntry) {
                    final eIdx = epEntry.key;
                    final ep = epEntry.value;
                    final isLastWatched = _history != null &&
                        _history!.lastGroupIndex == gIdx &&
                        _history!.lastEpisodeIndex == eIdx;
                    return ActionChip(
                      avatar: isLastWatched
                          ? const Icon(Icons.play_arrow,
                              size: 16, color: Colors.redAccent)
                          : null,
                      label: Text(ep.name),
                      onPressed: () => widget.onPlay(
                        ep,
                        groups,
                        resumeSeconds: isLastWatched
                            ? _history!.lastPositionSeconds
                            : null,
                        groupIndex: gIdx,
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
