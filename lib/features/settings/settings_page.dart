import 'package:flutter/material.dart';

import '../../core/builtin_configs.dart';
import '../../core/config_loader.dart';
import '../../data/app_store.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _store = AppStore();
  final _urlController = TextEditingController();
  String? _current;
  bool _saving = false;

  int _skipOpening = 0;
  int _skipEnding = 0;
  bool _autoPlayNext = true;
  String _defaultQuality = 'auto';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final url = await _store.getConfigUrl();
    final op = await _store.getSkipOpening();
    final ed = await _store.getSkipEnding();
    final ap = await _store.getAutoPlayNext();
    final dq = await _store.getDefaultQuality();
    if (!mounted) return;
    setState(() {
      _current = url;
      _urlController.text = url ?? '';
      _skipOpening = op;
      _skipEnding = ed;
      _autoPlayNext = ap;
      _defaultQuality = dq;
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _useBuiltin(BuiltinConfig config) async {
    setState(() {
      _saving = true;
      _urlController.text = config.url;
    });
    try {
      await config.loadJson();
      await _store.setConfigUrl(config.url);
      if (!mounted) return;
      setState(() => _current = config.url);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已切换到「${config.name}」')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('配置加载失败：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    setState(() => _saving = true);
    try {
      await loadTvboxConfig(url);
      await _store.setConfigUrl(url);
      if (!mounted) return;
      setState(() => _current = url);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('配置已保存')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('配置加载失败：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // 1. 配置源管理
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child:
                Text('内置配置源', style: Theme.of(context).textTheme.titleMedium),
          ),
          RadioGroup<String>(
            groupValue: _current,
            onChanged: (url) {
              if (url == null) return;
              final config =
                  BuiltinConfigs.all.where((c) => c.url == url).firstOrNull;
              if (config != null) _useBuiltin(config);
            },
            child: Column(
              children: BuiltinConfigs.all
                  .map((c) => RadioListTile<String>(
                        value: c.url,
                        title: Text(c.name),
                        subtitle: const Text('本地打包，无需外部接口，稳定直连',
                            style: TextStyle(fontSize: 12)),
                      ))
                  .toList(),
            ),
          ),
          const Divider(),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: '自定义配置接口地址',
              hintText: 'https://example.com/config.json',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('保存并验证'),
          ),
          if (_current != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text('当前配置：$_current',
                  style: const TextStyle(fontSize: 12, color: Colors.white54)),
            ),
          const SizedBox(height: 16),
          const Divider(),
          // 2. 播放偏好设置（片头片尾/自动连播/画质偏好）
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('播放偏好设置',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          ListTile(
            title: const Text('跳过片头'),
            subtitle: Text(_skipOpening > 0 ? '起播自动跳过 $_skipOpening 秒' : '不跳过'),
            trailing: DropdownButton<int>(
              value: _skipOpening,
              items: const [0, 30, 60, 90, 100, 120, 150]
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s == 0 ? '关' : '$s 秒'),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _skipOpening = v);
                _store.setSkipOpening(v);
              },
            ),
          ),
          ListTile(
            title: const Text('跳过片尾'),
            subtitle: Text(_skipEnding > 0 ? '距离结束 $_skipEnding 秒跳下一集' : '不跳过'),
            trailing: DropdownButton<int>(
              value: _skipEnding,
              items: const [0, 30, 60, 90, 100, 120, 150]
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s == 0 ? '关' : '$s 秒'),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _skipEnding = v);
                _store.setSkipEnding(v);
              },
            ),
          ),
          SwitchListTile(
            title: const Text('自动连播下一集'),
            subtitle: const Text('当前集播放完毕或跳过片尾时自动起播下一集'),
            value: _autoPlayNext,
            onChanged: (v) {
              setState(() => _autoPlayNext = v);
              _store.setAutoPlayNext(v);
            },
          ),
          ListTile(
            title: const Text('默认清晰度偏好'),
            subtitle: const Text('多码率视频流起播时优先选择的清晰度档位'),
            trailing: DropdownButton<String>(
              value: _defaultQuality,
              items: const [
                DropdownMenuItem(value: 'auto', child: Text('自动 (自适应)')),
                DropdownMenuItem(value: '1080', child: Text('1080P 超清')),
                DropdownMenuItem(value: '720', child: Text('720P 高清')),
                DropdownMenuItem(value: '480', child: Text('480P 标清')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _defaultQuality = v);
                _store.setDefaultQuality(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}
