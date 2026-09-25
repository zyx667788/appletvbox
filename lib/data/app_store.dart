import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';


/// 配置源、历史、收藏的本地存储。
class AppStore {
  static const configKey = 'tvbox.config.url';
  static const historyKey = 'tvbox.history';
  static const favoritesKey = 'tvbox.favorites';

  Future<String?> getConfigUrl() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(configKey);
  }

  Future<void> setConfigUrl(String url) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(configKey, url);
  }

  Future<List<HistoryEntry>> getHistory() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getStringList(historyKey) ?? [];
    return raw.map((e) => HistoryEntry.fromJsonString(e)).where((e) => e != null).cast<HistoryEntry>().toList();
  }

  Future<void> addHistory(HistoryEntry entry) async {
    final list = await getHistory();
    list.removeWhere((e) => e.vodId == entry.vodId && e.siteKey == entry.siteKey);
    list.insert(0, entry);
    if (list.length > 200) list.removeRange(200, list.length);
    await _saveList(historyKey, list);
  }

  Future<void> clearHistory() => _saveList(historyKey, []);

  Future<List<FavoriteEntry>> getFavorites() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getStringList(favoritesKey) ?? [];
    return raw.map((e) => FavoriteEntry.fromJsonString(e)).where((e) => e != null).cast<FavoriteEntry>().toList();
  }

  Future<bool> isFavorite(String siteKey, int vodId) async {
    final list = await getFavorites();
    return list.any((e) => e.siteKey == siteKey && e.vodId == vodId);
  }

  Future<void> toggleFavorite(FavoriteEntry entry) async {
    final list = await getFavorites();
    final exists = list.any((e) => e.siteKey == entry.siteKey && e.vodId == entry.vodId);
    if (exists) {
      list.removeWhere((e) => e.siteKey == entry.siteKey && e.vodId == entry.vodId);
    } else {
      list.insert(0, entry);
    }
    await _saveList(favoritesKey, list);
  }

  Future<void> _saveList(String key, List<dynamic> list) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(key, list.map((e) => jsonEncode(e.toJson())).toList());
  }
}

class HistoryEntry {
  final String siteKey;
  final String siteName;
  final int vodId;
  final String vodName;
  final String? pic;
  final String? note;
  final int watchedAt;

  HistoryEntry({
    required this.siteKey,
    required this.siteName,
    required this.vodId,
    required this.vodName,
    this.pic,
    this.note,
    required this.watchedAt,
  });

  Map<String, dynamic> toJson() => {
        'siteKey': siteKey,
        'siteName': siteName,
        'vodId': vodId,
        'vodName': vodName,
        'pic': pic,
        'note': note,
        'watchedAt': watchedAt,
      };

  static HistoryEntry? fromJsonString(String s) {
    try {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return HistoryEntry(
        siteKey: map['siteKey'] as String,
        siteName: map['siteName'] as String,
        vodId: map['vodId'] as int,
        vodName: map['vodName'] as String,
        pic: map['pic'] as String?,
        note: map['note'] as String?,
        watchedAt: map['watchedAt'] as int,
      );
    } catch (_) {
      return null;
    }
  }
}

class FavoriteEntry {
  final String siteKey;
  final String siteName;
  final int vodId;
  final String vodName;
  final String? pic;
  final String? note;

  FavoriteEntry({
    required this.siteKey,
    required this.siteName,
    required this.vodId,
    required this.vodName,
    this.pic,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'siteKey': siteKey,
        'siteName': siteName,
        'vodId': vodId,
        'vodName': vodName,
        'pic': pic,
        'note': note,
      };

  static FavoriteEntry? fromJsonString(String s) {
    try {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return FavoriteEntry(
        siteKey: map['siteKey'] as String,
        siteName: map['siteName'] as String,
        vodId: map['vodId'] as int,
        vodName: map['vodName'] as String,
        pic: map['pic'] as String?,
        note: map['note'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
