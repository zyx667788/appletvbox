import 'package:flutter/material.dart';

import '../../core/json_vod_client.dart';
import '../../data/app_store.dart';
import '../../models/tvbox_config.dart';

class DetailPage extends StatefulWidget {
  final Site site;
  final JsonVodClient client;
  final VodItem item;
  final void Function(Episode episode, List<PlayGroup> groups) onPlay;

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

  @override
  void initState() {
    super.initState();
    _isFavorite = false;
    _store.isFavorite(widget.site.key, widget.item.id).then((v) {
      if (mounted) setState(() { _isFavorite = v; _favoriteLoaded = true; });
    });
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
                  child: Image.network(widget.item.pic!, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(color: Colors.grey[850])),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.item.name, style: Theme.of(context).textTheme.titleLarge),
                    if (widget.item.type != null) Text('类型：${widget.item.type}'),
                    if (widget.item.note != null) Text('备注：${widget.item.note}'),
                    if (widget.item.actor != null && widget.item.actor!.isNotEmpty)
                      Text('演员：${widget.item.actor}', maxLines: 3, overflow: TextOverflow.ellipsis),
                    if (widget.item.director != null && widget.item.director!.isNotEmpty)
                      Text('导演：${widget.item.director}'),
                  ],
                ),
              ),
            ],
          ),
          if (widget.item.descr != null && widget.item.descr!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(widget.item.descr!.replaceAll(RegExp(r'<[^>]+>'), ''), maxLines: 6, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 12),
          ...groups.map((group) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(group.name, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: group.episodes
                        .map((ep) => ActionChip(
                              label: Text(ep.name),
                              onPressed: () => widget.onPlay(ep, groups),
                            ))
                        .toList(),
                  ),
                ],
              )),
        ],
      ),
    );
  }
}
