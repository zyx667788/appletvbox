import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/json_vod_client.dart';
import '../../data/app_store.dart';

class PlayerPage extends StatefulWidget {
  final String title;
  final String url;
  final List<Episode> episodes;
  final int initialIndex;
  final String Function(int index)? onSwitch;

  /// 播放线路组（多线路 = 多画质源）
  final List<PlayGroup>? groups;
  final int? initialGroupIndex;

  /// 续播与历史记录绑定参数
  final String? siteKey;
  final String? siteName;
  final int? vodId;
  final String? vodName;
  final String? vodPic;
  final String? vodNote;
  final int? initialPositionSeconds;

  const PlayerPage({
    super.key,
    required this.title,
    required this.url,
    required this.episodes,
    required this.initialIndex,
    this.onSwitch,
    this.groups,
    this.initialGroupIndex,
    this.siteKey,
    this.siteName,
    this.vodId,
    this.vodName,
    this.vodPic,
    this.vodNote,
    this.initialPositionSeconds,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final _store = AppStore();
  late final Player _player;
  late final VideoController _controller;
  late int _episodeIndex;
  late int _groupIndex;
  late List<PlayGroup> _groups;

  double _speed = 1.0;
  int _skipOpening = 0;
  int _skipEnding = 0;
  bool _autoPlayNext = true;
  String _preferredQuality = 'auto';

  bool _restoredInitialPosition = false;
  bool _skippedOpeningThisEpisode = false;
  bool _skippedEndingThisEpisode = false;
  int _lastSavedSecond = -1;

  StreamSubscription? _completedSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _tracksSub;

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
    _episodeIndex = widget.initialIndex >= 0 ? widget.initialIndex : 0;

    // 初始化 mpv 播放器并开启硬件解码
    _player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 32 * 1024 * 1024,
      ),
    );
    _controller = VideoController(_player);

    _loadSettingsAndStart();
  }

  Future<void> _loadSettingsAndStart() async {
    _skipOpening = await _store.getSkipOpening();
    _skipEnding = await _store.getSkipEnding();
    _autoPlayNext = await _store.getAutoPlayNext();
    _preferredQuality = await _store.getDefaultQuality();
    if (mounted) setState(() {});

    // 监听视频自然播放完成 -> 自动连播下一集
    _completedSub = _player.stream.completed.listen((completed) {
      if (completed && _autoPlayNext) {
        _autoPlayNextEpisode();
      }
    });

    // 监听播放位置 -> 跳片尾、断点进度保存、跳片头
    _positionSub = _player.stream.position.listen((pos) {
      _onPositionChanged(pos);
    });

    // 监听视频轨道 -> 自动匹配偏好画质
    _tracksSub = _player.stream.tracks.listen((tracks) {
      _applyQualityPreference(tracks);
    });

    // 起播当前集
    final episodes = _currentEpisodes;
    final startUrl = episodes.isNotEmpty ? episodes[_episodeIndex].url : widget.url;
    await _player.open(Media(startUrl));
  }

  @override
  void dispose() {
    _saveCurrentProgress();
    _completedSub?.cancel();
    _positionSub?.cancel();
    _tracksSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  List<Episode> get _currentEpisodes => _groups.isNotEmpty
      ? _groups[_groupIndex].episodes
      : widget.episodes;

  void _onPositionChanged(Duration pos) {
    final dur = _player.state.duration;
    if (dur <= Duration.zero) return;

    // 1. 初次起播恢复历史进度（续播）
    if (!_restoredInitialPosition &&
        widget.initialPositionSeconds != null &&
        widget.initialPositionSeconds! > 5) {
      _restoredInitialPosition = true;
      final target = Duration(seconds: widget.initialPositionSeconds!);
      if (target < dur) {
        _player.seek(target);
        _skippedOpeningThisEpisode = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已恢复至上次播放位置 ${_formatDuration(target)}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    }

    // 2. 自动跳过片头（仅当未恢复历史且当前处于片头区间时）
    if (!_skippedOpeningThisEpisode && _skipOpening > 0) {
      if (pos < Duration(seconds: _skipOpening) &&
          dur > Duration(seconds: _skipOpening + 15)) {
        _skippedOpeningThisEpisode = true;
        final target = Duration(seconds: _skipOpening);
        _player.seek(target);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已为您自动跳过片头 $_skipOpening 秒'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      } else if (pos >= Duration(seconds: _skipOpening)) {
        _skippedOpeningThisEpisode = true;
      }
    }

    // 3. 自动跳过片尾并连播下一集
    if (_skipEnding > 0 && !_skippedEndingThisEpisode && _autoPlayNext) {
      final remain = dur - pos;
      if (remain <= Duration(seconds: _skipEnding) &&
          dur > Duration(seconds: _skipEnding + 10)) {
        _skippedEndingThisEpisode = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已跳过片尾，自动播放下一集'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        _autoPlayNextEpisode();
        return;
      }
    }

    // 4. 定时保存播放历史（每 5 秒保存一次）
    final sec = pos.inSeconds;
    if (sec != _lastSavedSecond && sec % 5 == 0) {
      _lastSavedSecond = sec;
      _saveCurrentProgress();
    }
  }

  void _saveCurrentProgress() {
    if (widget.siteKey == null || widget.vodId == null) return;
    final episodes = _currentEpisodes;
    final epName = (_episodeIndex >= 0 && _episodeIndex < episodes.length)
        ? episodes[_episodeIndex].name
        : null;
    final pos = _player.state.position.inSeconds;
    final dur = _player.state.duration.inSeconds;

    _store.addHistory(HistoryEntry(
      siteKey: widget.siteKey!,
      siteName: widget.siteName ?? '',
      vodId: widget.vodId!,
      vodName: widget.vodName ?? widget.title,
      pic: widget.vodPic,
      note: widget.vodNote,
      watchedAt: DateTime.now().millisecondsSinceEpoch,
      lastEpisodeIndex: _episodeIndex,
      lastEpisodeName: epName,
      lastPositionSeconds: pos,
      totalDurationSeconds: dur,
      lastGroupIndex: _groupIndex,
    ));
  }

  void _autoPlayNextEpisode() {
    final episodes = _currentEpisodes;
    if (_episodeIndex + 1 < episodes.length) {
      _switchEpisode(_episodeIndex + 1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('正在播放下一集：${episodes[_episodeIndex].name}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('全部剧集已播放完毕'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _switchEpisode(int index) {
    final episodes = _currentEpisodes;
    if (index < 0 || index >= episodes.length) return;
    _saveCurrentProgress();
    setState(() {
      _episodeIndex = index;
      _skippedOpeningThisEpisode = false;
      _skippedEndingThisEpisode = false;
      _restoredInitialPosition = true; // 换集后不恢复旧集的秒数
    });
    final targetUrl = episodes[index].url;
    _player.open(Media(targetUrl));
  }

  void _switchGroup(int groupIdx) {
    if (groupIdx < 0 || groupIdx >= _groups.length) return;
    _saveCurrentProgress();
    setState(() {
      _groupIndex = groupIdx;
      if (_episodeIndex >= _groups[groupIdx].episodes.length) {
        _episodeIndex = 0;
      }
      _skippedOpeningThisEpisode = false;
      _skippedEndingThisEpisode = false;
      _restoredInitialPosition = true;
    });
    final episodes = _groups[groupIdx].episodes;
    if (episodes.isNotEmpty) {
      _player.open(Media(episodes[_episodeIndex].url));
    }
  }

  void _applyQualityPreference(Tracks tracks) {
    if (_preferredQuality == 'auto') return;
    final videoTracks = tracks.video.where((t) => t.id != 'no' && t.id != 'auto').toList();
    if (videoTracks.length <= 1) return;

    final targetH = int.tryParse(_preferredQuality);
    if (targetH == null) return;

    // 找最接近偏好分辨率的轨道
    VideoTrack? best;
    var minDiff = 999999;
    for (final t in videoTracks) {
      if (t.h != null) {
        final diff = (t.h! - targetH).abs();
        if (diff < minDiff) {
          minDiff = diff;
          best = t;
        }
      }
    }
    if (best != null && best.id != _player.state.track.video.id) {
      _player.setVideoTrack(best);
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
      if (track.h! >= 2160) return '4K 超清 (${track.w}x${track.h})';
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

  /// 播放器设置面板（随时调整跳片头片尾、自动连播）
  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                shrinkWrap: true,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text('播放设置',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: Colors.white)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12),
                  // 1. 跳过片头
                  ListTile(
                    dense: true,
                    title: const Text('跳过片头',
                        style: TextStyle(color: Colors.white)),
                    subtitle: Text(
                        _skipOpening > 0 ? '已设置跳过 $_skipOpening 秒' : '不跳过',
                        style: const TextStyle(color: Colors.white54)),
                    trailing: DropdownButton<int>(
                      value: _skipOpening,
                      dropdownColor: const Color(0xFF2A2A2A),
                      style: const TextStyle(color: Colors.white),
                      underline: const SizedBox(),
                      items: const [0, 30, 60, 90, 100, 120, 150]
                          .map((s) => DropdownMenuItem<int>(
                                value: s,
                                child: Text(s == 0 ? '关' : '$s 秒'),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        setSheetState(() => _skipOpening = val);
                        setState(() => _skipOpening = val);
                        _store.setSkipOpening(val);
                      },
                    ),
                  ),
                  // 2. 跳过片尾
                  ListTile(
                    dense: true,
                    title: const Text('跳过片尾',
                        style: TextStyle(color: Colors.white)),
                    subtitle: Text(
                        _skipEnding > 0 ? '提前 $_skipEnding 秒跳下一集' : '不跳过',
                        style: const TextStyle(color: Colors.white54)),
                    trailing: DropdownButton<int>(
                      value: _skipEnding,
                      dropdownColor: const Color(0xFF2A2A2A),
                      style: const TextStyle(color: Colors.white),
                      underline: const SizedBox(),
                      items: const [0, 30, 60, 90, 100, 120, 150]
                          .map((s) => DropdownMenuItem<int>(
                                value: s,
                                child: Text(s == 0 ? '关' : '$s 秒'),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        setSheetState(() => _skipEnding = val);
                        setState(() => _skipEnding = val);
                        _store.setSkipEnding(val);
                      },
                    ),
                  ),
                  // 3. 自动连播下一集
                  SwitchListTile(
                    dense: true,
                    title: const Text('自动连播下一集',
                        style: TextStyle(color: Colors.white)),
                    subtitle: const Text('本集播完或跳过片尾时自动起播下一集',
                        style: TextStyle(color: Colors.white54)),
                    value: _autoPlayNext,
                    onChanged: (enable) {
                      setSheetState(() => _autoPlayNext = enable);
                      setState(() => _autoPlayNext = enable);
                      _store.setAutoPlayNext(enable);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '播放设置（片头片尾/连播）',
            onPressed: _showSettingsBottomSheet,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 视频展示区域：按 16:9 居中契合，防止在大屏/横屏挤占控制栏
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
            // 控制栏：快退/快进、切集、播放/暂停、清晰度选择、倍速选择
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
                            tooltip: '切换清晰度',
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
                                  content: Text(
                                      '已切换清晰度：${_formatTrackName(track)}'),
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
                            padding: const EdgeInsets.only(
                                right: 6, top: 4, bottom: 4),
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
