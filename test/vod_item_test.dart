import 'package:flutter_test/flutter_test.dart';
import 'package:appletvbox/core/json_vod_client.dart';

void main() {
  test('vod_play_url 拆分播放组与剧集', () {
    final item = VodItem(
      id: 1,
      name: '测试剧',
      playFrom: r'线路一$$$线路二',
      playUrl: r'第1集$http://a/1.m3u8#第2集$http://a/2.m3u8$$$第1集$http://b/1.m3u8',
    );
    final groups = item.playGroups;
    expect(groups.length, 2);
    expect(groups[0].name, '线路一');
    expect(groups[0].episodes.length, 2);
    expect(groups[0].episodes[1].url, 'http://a/2.m3u8');
    expect(groups[1].episodes[0].url, 'http://b/1.m3u8');
  });

  test('空 playUrl 返回空组', () {
    final item = VodItem(id: 1, name: 'x');
    expect(item.playGroups, isEmpty);
  });
}
