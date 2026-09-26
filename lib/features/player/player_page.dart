import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/json_vod_client.dart';

class PlayerPage extends StatefulWidget {
  final String title;
  final String url;
  final List<Episode> episodes;
  final int initialIndex;
  final String Function(int index)? onSwitch;

  /// 可选：完整的播放线路组，用于在播放页直接切换清晰度源/线路
  final List<PlayGroup>? groups;
  final int? initialGroupIndex;

  const PlayerPage({
    super.key,
    required this.title,
    required this.url,
    required this.episodes,
    required this.initialIndex,
    this.onSwitch,
    this.groups,
    this.initialGroupIndex,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final Player _player;
  late final VideoController _controller;
  late int _episodeIndex;
  late int _groupIndex;
  late List<PlayGroup> _groups;
  double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    _groups = widget.groups ??
        [
          PlayGroup(
            name: '默认线路',
            episodes: widget.episodes,
          )
        ];
    _groupIndex = (widget.initialGroupIndex != null &&
            widget.initialGroupIndex! >= 0 &&
            widget.initialGroupIndex! < _groups.length)
        ? widget.initialGroupIndex!
        : 0;
    _episodeIndex =
        widget.initialIndex >= 0 ? widget.initialIndex : 0;

    _player = Player();
    _controller = VideoController(_player);
    _player.open(Media(widget.url));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  List<Episode> get _currentEpisodes => _groups.isNotEmpty
      ? _groups[_groupIndex].episodes
      : widget.episodes;

  void _switchEpisode(int index) {
    final episodes = _currentEpisodes;
    if (index < 0 || index >= episodes.length) return;
    setState(() => _episodeIndex = index);
    final targetUrl = episodes[index].url;
    _player.open(Media(targetUrl));
  }

  void _switchGroup(int groupIdx) {
    if (groupIdx < 0 || groupIdx >= _groups.length) return;
    setState(() {
      _groupIndex = groupIdx;
      if (_episodeIndex >= _groups[groupIdx].episodes.length) {
        _episodeIndex = 0;
      }
    });
    final episodes = _groups[groupIdx].episodes;
    if (episodes.isNotEmpty) {
      _player.open(Media(episodes[_episodeIndex].url));
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$m:$s';
    }
    return '$m:$s';
  }

  String _formatTrackName(VideoTrack track) {
    if (track.id == 'auto') return '自动 (自适应)';
    if (track.h != null && track.h! > 0) {
      if (track.h! >= 2160) return '4K 超高清 (${track.w}x${track.h})';
      if (track.h! >= 1080) return '1080P 全高清 (${track.w}x${track.h})';
      if (track.h! >= 720) return '720P 高清 (${track.w}x${track.h})';
      if (track.h! >= 480) return '480P 标清 (${track.w}x${track.h})';
      return '${track.h}P (${track.w}x${track.h})';
    }
    if (track.title != null && track.title!.isNotEmpty) {
      return track.title!;
    }
    return '清晰度 ${track.id}';
  }

  @override
  Widget build(BuildContext context) {
    final episodes = _currentEpisodes;
    final epName = (_episodeIndex >= 0 && _episodeIndex < episodes.length)
        ? episodes[_episodeIndex].name
        : '';
    final currentTitle = epName.isNotEmpty ? '${widget.title} $epName' : widget.title;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(currentTitle),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Video(controller: _controller),
                ),
              ),
            ),
            // 进度条与播放时间
            StreamBuilder<Duration>(
              stream: _player.stream.position,
              builder: (context, posSnap) {
                final pos = posSnap.data ?? Duration.zero;
                return StreamBuilder<Duration>(
                  stream: _player.stream.duration,
                  builder: (context, durSnap) {
                    final dur = durSnap.data ?? Duration.zero;
                    final maxSec = dur.inSeconds.toDouble();
                    final curSec = pos.inSeconds
                        .toDouble()
                        .clamp(0.0, maxSec > 0 ? maxSec : 0.0);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Text(
                            _formatDuration(pos),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11),
                          ),
                          Expanded(
                            child: Slider(
                              value: curSec,
                              max: maxSec > 0 ? maxSec : 1.0,
                              onChanged: maxSec > 0
                                  ? (val) {
                                      _player.seek(Duration(seconds: val.toInt()));
                                    }
                                  : null,
                            ),
                          ),
                          Text(
                            _formatDuration(dur),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            // 控制栏：切集、播放/暂停、清晰度选择、倍速选择
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay_10),
                    color: Colors.white,
                    tooltip: '快退 10 秒',
                    onPressed: () {
                      final cur = _player.state.position;
                      final target = cur - const Duration(seconds: 10);
                      _player.seek(target < Duration.zero ? Duration.zero : target);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    color: Colors.white,
                    tooltip: '上一集',
                    onPressed: () => _switchEpisode(_episodeIndex - 1),
                  ),
                  StreamBuilder<bool>(
                    stream: _player.stream.playing,
                    builder: (_, snap) => IconButton(
                      icon: Icon(
                          snap.data == true ? Icons.pause : Icons.play_arrow),
                      color: Colors.white,
                      onPressed: () => _player.playOrPause(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    color: Colors.white,
                    tooltip: '下一集',
                    onPressed: () => _switchEpisode(_episodeIndex + 1),
                  ),
                  IconButton(
                    icon: const Icon(Icons.forward_10),
                    color: Colors.white,
                    tooltip: '快进 10 秒',
                    onPressed: () {
                      final cur = _player.state.position;
                      final dur = _player.state.duration;
                      final target = cur + const Duration(seconds: 10);
                      _player.seek(target > dur ? dur : target);
                    },
                  ),
                  const Spacer(),
                  // 视频流清晰度选择菜单（支持 HLS 多码率 / 自适应轨道切换）
                  StreamBuilder<Tracks>(
                    stream: _player.stream.tracks,
                    builder: (context, trackSnap) {
                      final tracks = trackSnap.data ?? _player.state.tracks;
                      final videoTracks =
                          tracks.video.where((t) => t.id != 'no').toList();
                      return StreamBuilder<Track>(
                        stream: _player.stream.track,
                        builder: (context, _) {
                          final currentVideoTrack = _player.state.track.video;
                          var qualityLabel = '画质';
                          if (currentVideoTrack.h != null &&
                              currentVideoTrack.h! > 0) {
                            qualityLabel = '${currentVideoTrack.h}P';
                          } else if (currentVideoTrack.id == 'auto') {
                            final first = videoTracks
                                .where((t) => t.h != null && t.h! > 0)
                                .firstOrNull;
                            qualityLabel =
                                first != null ? '${first.h}P' : '自动';
                          }

                          return PopupMenuButton<VideoTrack>(
                            tooltip: '清晰度',
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: Colors.white70, width: 1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                qualityLabel,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            onSelected: (track) {
                              _player.setVideoTrack(track);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('已切换清晰度：${_formatTrackName(track)}'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            itemBuilder: (_) {
                              if (videoTracks.length <= 1) {
                                final h = videoTracks.firstOrNull?.h;
                                return [
                                  PopupMenuItem(
                                    enabled: false,
                                    child: Text(h != null
                                        ? '源站提供固定画质 (${h}P)'
                                        : '当前源为单一清晰度'),
                                  ),
                                ];
                              }
                              return videoTracks.map((t) {
                                final isSelected =
                                    t.id == currentVideoTrack.id;
                                return PopupMenuItem<VideoTrack>(
                                  value: t,
                                  child: Row(
                                    children: [
                                      if (isSelected)
                                        const Icon(Icons.check,
                                            size: 16, color: Colors.redAccent)
                                      else
                                        const SizedBox(width: 16),
                                      const SizedBox(width: 8),
                                      Text(_formatTrackName(t)),
                                    ],
                                  ),
                                );
                              }).toList();
                            },
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  // 倍速播放菜单
                  PopupMenuButton<double>(
                    tooltip: '播放倍速',
                    icon: const Icon(Icons.speed, color: Colors.white, size: 20),
                    onSelected: (v) {
                      setState(() => _speed = v);
                      _player.setRate(v);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 0.5, child: Text('0.5x')),
                      PopupMenuItem(value: 0.75, child: Text('0.75x')),
                      PopupMenuItem(value: 1.0, child: Text('1.0x (正常)')),
                      PopupMenuItem(value: 1.25, child: Text('1.25x')),
                      PopupMenuItem(value: 1.5, child: Text('1.5x')),
                      PopupMenuItem(value: 2.0, child: Text('2.0x')),
                    ],
                  ),
                  Text('${_speed}x',
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
            // 多线路画质源切换（如果存在多个播放线路）
            if (_groups.length > 1) ...[
              const Divider(color: Colors.white12, height: 1),
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    const Text('线路: ',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Expanded(
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _groups.length,
                        itemBuilder: (context, idx) {
                          final selected = idx == _groupIndex;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
                            child: ChoiceChip(
                              label: Text(_groups[idx].name,
                                  style: const TextStyle(fontSize: 11)),
                              selected: selected,
                              onSelected: (_) => _switchGroup(idx),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(color: Colors.white24, height: 1),
            // 剧集选择列表
            Expanded(
              flex: 4,
              child: ListView.builder(
                itemCount: episodes.length,
                itemBuilder: (context, eIdx) {
                  final selected = eIdx == _episodeIndex;
                  return ListTile(
                    dense: true,
                    textColor: Colors.white,
                    selectedColor: Theme.of(context).colorScheme.primary,
                    selected: selected,
                    leading: Icon(
                      selected
                          ? Icons.play_circle_filled
                          : Icons.play_circle_outline,
                      size: 20,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white54,
                    ),
                    title: Text(episodes[eIdx].name),
                    trailing: selected
                        ? const Text('播放中',
                            style: TextStyle(
                                color: Colors.redAccent, fontSize: 11))
                        : null,
                    onTap: () => _switchEpisode(eIdx),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
