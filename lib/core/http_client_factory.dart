import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// 共享 HTTP 客户端工厂。
///
/// 手机网络常见的 DNS 污染会让 raw.githubusercontent.com、部分源站等域名
/// 解析失败（errno = 7）。系统 DNS 失败时自动改用 DoH（阿里 223.5.5.5，
/// 备用 Cloudflare 1.1.1.1）查询真实 IP 后直连，TLS 仍按原域名校验。
http.Client createHttpClient() {
  final inner = HttpClient()
    ..connectionFactory = _connectionFactory
    ..connectionTimeout = const Duration(seconds: 12);
  return IOClient(inner);
}

class _Entry {
  final List<InternetAddress> addrs;
  final DateTime expiresAt;
  _Entry(this.addrs, this.expiresAt);
}

final Map<String, _Entry> _dnsCache = {};

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

  _dnsCache[name] = _Entry(
    addrs,
    DateTime.now().add(const Duration(minutes: 10)),
  );
  return addrs;
}

Future<List<InternetAddress>> _dohLookup(String name) async {
  for (final endpoint in const [
    'https://223.5.5.5/resolve?name=#HOST#&type=A',
    'https://1.1.1.1/dns-query?name=#HOST#&type=A',
  ]) {
    try {
      final uri = Uri.parse(endpoint.replaceAll('#HOST#', name));
      final dohClient = HttpClient();
      final req = await dohClient.getUrl(uri);
      req.headers.set(HttpHeaders.acceptHeader, 'application/dns-json');
      final res = await req.close().timeout(const Duration(seconds: 8));
      dohClient.close();
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
    } catch (_) {
      continue;
    }
  }
  return const [];
}
