import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// 共享 HTTP 客户端工厂。
///
/// 手机网络常见的 DNS 污染/拦截会让域名解析失败（errno = 7）。
/// 系统 DNS 失败时自动改用 DoH（阿里 223.5.5.5、腾讯 120.53.53.53、
/// Cloudflare 1.1.1.1）查询真实 IP 后直连，TLS 仍按原域名校验。
http.Client createHttpClient() {
  final inner = HttpClient()
    ..connectionFactory = _connectionFactory
    ..connectionTimeout = const Duration(seconds: 15);
  return IOClient(inner);
}

class _Entry {
  final List<InternetAddress> addrs;
  final DateTime expiresAt;
  _Entry(this.addrs, this.expiresAt);
}

final Map<String, _Entry> _dnsCache = {};

/// 网络诊断：返回每一跳的结果，供设置页展示。
Future<Map<String, String>> diagnoseHost(String host) async {
  final result = <String, String>{};
  try {
    final addrs = await InternetAddress.lookup(
      host,
      type: InternetAddressType.IPv4,
    ).timeout(const Duration(seconds: 5));
    result['系统DNS'] = addrs.map((a) => a.address).join(', ');
  } catch (e) {
    result['系统DNS'] = '失败（$e）';
  }
  final doh = await _dohLookup(host);
  result['DoH'] = doh.isEmpty ? '失败' : doh.map((a) => a.address).join(', ');
  if (doh.isNotEmpty) {
    try {
      final socket = await Socket.connect(
        doh.first,
        443,
        timeout: const Duration(seconds: 8),
      );
      socket.destroy();
      result['TCP连接'] = '成功（${doh.first.address}:443）';
    } catch (e) {
      result['TCP连接'] = '失败（$e）';
    }
  }
  return result;
}

Future<ConnectionTask<Socket>> _connectionFactory(
  Uri host,
  String? proxyHost,
  int? proxyPort,
) async {
  final name = proxyHost ?? host.host;
  final port = proxyPort ??
      (host.port == 0 ? (host.scheme == 'https' ? 443 : 80) : host.port);

  var addrs = await _resolve(name);
  if (addrs.isEmpty) {
    throw SocketException('Failed host lookup: $name');
  }
  return Socket.startConnect(addrs.first, port);
}

Future<List<InternetAddress>> _resolve(String name) async {
  final cached = _dnsCache[name];
  if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
    return cached.addrs;
  }

  List<InternetAddress> addrs = const [];
  try {
    addrs = await InternetAddress.lookup(
      name,
      type: InternetAddressType.IPv4,
    ).timeout(const Duration(seconds: 5));
  } catch (_) {
    addrs = const [];
  }

  if (addrs.isEmpty) {
    addrs = await _dohLookup(name);
  }

  // 只有拿到真实结果才缓存，避免把失败缓存住。
  if (addrs.isNotEmpty) {
    _dnsCache[name] = _Entry(
      addrs,
      DateTime.now().add(const Duration(minutes: 10)),
    );
  }
  return addrs;
}

Future<List<InternetAddress>> _dohLookup(String name) async {
  for (final endpoint in const [
    'https://223.5.5.5/resolve?name=#HOST#&type=A',
    'https://120.53.53.53/dns-query?name=#HOST#&type=A',
    'https://1.1.1.1/dns-query?name=#HOST#&type=A',
  ]) {
    try {
      final uri = Uri.parse(endpoint.replaceAll('#HOST#', name));
      final client = HttpClient();
      try {
        final req = await client
            .getUrl(uri)
            .timeout(const Duration(seconds: 8));
        req.headers.set(HttpHeaders.acceptHeader, 'application/dns-json');
        final res = await req.close().timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) continue;
        final body = await res.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final answers = json['Answer'];
        if (answers is! List) continue;
        final addrs = <InternetAddress>[];
        for (final a in answers) {
          if (a is Map<String, dynamic> && a['type'] == 1) {
            final data = a['data']?.toString();
            if (data != null && InternetAddress.tryParse(data) != null) {
              addrs.add(InternetAddress(data));
            }
          }
        }
        if (addrs.isNotEmpty) return addrs;
      } finally {
        client.close();
      }
    } catch (_) {
      continue;
    }
  }
  return const [];
}
