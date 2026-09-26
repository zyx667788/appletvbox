import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 配置源、播放设置、历史、收藏的本地存储。
class AppStore {
  static const proxyKey = 'tvbox.proxy';
  static const configKey = 'tvbox.config.url';
  static const historyKey = 'tvbox.history';
  static const favoritesKey = 'tvbox.favorites';

  // 播放器通用设置
  static const skipOpeningKey = 'tvbox.skip_opening';
  static const skipEndingKey = 'tvbox.skip_ending';
  static const autoPlayNextKey = 'tvbox.auto_play_next';
  static const defaultQualityKey = 'tvbox.default_quality';

  Future<String?> getConfigUrl() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(configKey);
  }

  Future<void> setConfigUrl(String url) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(configKey, url);
  }

  Future<String?> getProxy() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(proxyKey);
  }

  Future<void> setProxy(String? value) async {
    final sp = await SharedPreferences.getInstance();
    if (value == null || value.isEmpty) {
      await sp.remove(proxyKey);
    } else {
      await sp.setString(proxyKey, value);
    }
  }

  /// 跳过片头秒数（默认 0 秒）
  Future<int> getSkipOpening() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(skipOpeningKey) ?? 0;
  }

  Future<void> setSkipOpening(int seconds) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(skipOpeningKey, seconds);
  }

  /// 跳过片尾秒数（默认 0 秒）
  Future<int> getSkipEnding() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(skipEndingKey) ?? 0;
  }

  Future<void> setSkipEnding(int seconds) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(skipEndingKey, seconds);
  }

  /// 自动连播下一集（默认开启）
  Future<bool> getAutoPlayNext() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(autoPlayNextKey) ?? true;
  }

  Future<void> setAutoPlayNext(bool enable) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(autoPlayNextKey, enable);
  }

  /// 默认画质偏好（auto / 1080 / 720 / 480）
  Future<String> getDefaultQuality() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(defaultQualityKey) ?? 'auto';
  }

  Future<void> setDefaultQuality(String quality) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(defaultQualityKey, quality);
  }

  Future<List<HistoryEntry>> getHistory() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getStringList(historyKey) ?? [];
    return raw
        .map((e) => HistoryEntry.fromJsonString(e))
        .where((e) => e != null)
        .cast<HistoryEntry>()
        .toList();
  }

  Future<HistoryEntry?> getHistoryFor(String siteKey, int vodId) async {
    final list = await getHistory();
    for (final e in list) {
      if (e.siteKey == siteKey && e.vodId == vodId) return e;
    }
    return null;
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
    return raw
        .map((e) => FavoriteEntry.fromJsonString(e))
        .where((e) => e != null)
        .cast<FavoriteEntry>()
        .toList();
  }

  Future<bool> isFavorite(String siteKey, int vodId) async {
    final list = await getFavorites();
    return list.any((e) => e.siteKey == siteKey && e.vodId == vodId);
  }

  Future<void> toggleFavorite(FavoriteEntry entry) async {
    final list = await getFavorites();
    final exists =
        list.any((e) => e.siteKey == entry.siteKey && e.vodId == entry.vodId);
    if (exists) {
      list.removeWhere(
          (e) => e.siteKey == entry.siteKey && e.vodId == entry.vodId);
    } else {
      list.insert(0, entry);
    }
    await _saveList(favoritesKey, list);
  }

  Future<void> _saveList(String key, List<dynamic> list) async {
    final sp = await SharedPreferences.getInstance();
    await sp
        .setStringList(key, list.map((e) => jsonEncode(e.toJson())).toList());
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

  // 续播扩展字段
  final int lastEpisodeIndex;
  final String? lastEpisodeName;
  final int lastPositionSeconds;
  final int totalDurationSeconds;
  final int lastGroupIndex;

  HistoryEntry({
    required this.siteKey,
    required this.siteName,
    required this.vodId,
    required this.vodName,
    this.pic,
    this.note,
    required this.watchedAt,
    this.lastEpisodeIndex = 0,
    this.lastEpisodeName,
    this.lastPositionSeconds = 0,
    this.totalDurationSeconds = 0,
    this.lastGroupIndex = 0,
  });

  Map<String, dynamic> toJson() => {
        'siteKey': siteKey,
        'siteName': siteName,
        'vodId': vodId,
        'vodName': vodName,
        'pic': pic,
        'note': note,
        'watchedAt': watchedAt,
        'lastEpisodeIndex': lastEpisodeIndex,
        'lastEpisodeName': lastEpisodeName,
        'lastPositionSeconds': lastPositionSeconds,
        'totalDurationSeconds': totalDurationSeconds,
        'lastGroupIndex': lastGroupIndex,
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
        lastEpisodeIndex: map['lastEpisodeIndex'] as int? ?? 0,
        lastEpisodeName: map['lastEpisodeName'] as String?,
        lastPositionSeconds: map['lastPositionSeconds'] as int? ?? 0,
        totalDurationSeconds: map['totalDurationSeconds'] as int? ?? 0,
        lastGroupIndex: map['lastGroupIndex'] as int? ?? 0,
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
