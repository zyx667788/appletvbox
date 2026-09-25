import 'package:flutter/material.dart';

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

  Future<void> _save() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    setState(() => _saving = true);
    try {
      // 先验证配置可用再保存，避免坏 URL 进入首页。
      await loadTvboxConfig(url);
      await _store.setConfigUrl(url);
      if (!mounted) return;
      setState(() => _current = url);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('配置已保存')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('配置加载失败：$e')));
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
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: '配置接口地址',
              hintText: 'https://example.com/config.json',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('保存并验证'),
          ),
          if (_current != null) Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('当前配置：$_current'),
          ),
        ],
      ),
    );
  }
}
