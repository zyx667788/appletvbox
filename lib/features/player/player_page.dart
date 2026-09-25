import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/json_vod_client.dart';

class PlayerPage extends StatefulWidget {
  final String title;
  final String url;
  final List<Episode> episodes;
  final int initialIndex;
  final String Function(int index) onSwitch;

  const PlayerPage({
    super.key,
    required this.title,
    required this.url,
    required this.episodes,
    required this.initialIndex,
    required this.onSwitch,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final Player _player;
  late final VideoController _controller;
  late int _index;
  double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex >= 0 ? widget.initialIndex : 0;
    _player = Player();
    _controller = VideoController(_player);
    _player.open(Media(widget.url));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _switchEpisode(int index) {
    if (index < 0 || index >= widget.episodes.length) return;
    setState(() => _index = index);
    _player.open(Media(widget.onSwitch(index)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Video(controller: _controller),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    color: Colors.white,
                    onPressed: () => _switchEpisode(_index - 1),
                  ),
                  StreamBuilder<bool>(
                    stream: _player.stream.playing,
                    builder: (_, snap) => IconButton(
                      icon: Icon(snap.data == true ? Icons.pause : Icons.play_arrow),
                      color: Colors.white,
                      onPressed: () => _player.playOrPause(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    color: Colors.white,
                    onPressed: () => _switchEpisode(_index + 1),
                  ),
                  const Spacer(),
                  PopupMenuButton<double>(
                    icon: const Icon(Icons.speed, color: Colors.white),
                    onSelected: (v) {
                      setState(() => _speed = v);
                      _player.setRate(v);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 0.5, child: Text('0.5x')),
                      PopupMenuItem(value: 1.0, child: Text('1.0x')),
                      PopupMenuItem(value: 1.25, child: Text('1.25x')),
                      PopupMenuItem(value: 1.5, child: Text('1.5x')),
                      PopupMenuItem(value: 2.0, child: Text('2.0x')),
                    ],
                  ),
                  Text('${_speed}x', style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: widget.episodes
                    .asMap()
                    .entries
                    .map<Widget>((e) => ListTile(
                          dense: true,
                          textColor: Colors.white,
                          selected: e.key == _index,
                          title: Text(e.value.name),
                          onTap: () => _switchEpisode(e.key),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
