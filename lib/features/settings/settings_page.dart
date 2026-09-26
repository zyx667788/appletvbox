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

  @override
  void initState() {
    super.initState();
    _store.getConfigUrl().then((url) {
      if (!mounted) return;
      setState(() {
        _current = url;
        _urlController.text = url ?? '';
      });
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
      // 内置源直接读 App 内打包的配置文件，不联网。
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
                        subtitle: const Text('来自 GitHub 公开源',
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
              padding: const EdgeInsets.only(top: 12),
              child: Text('当前配置：$_current'),
            ),
        ],
      ),
    );
  }
}
