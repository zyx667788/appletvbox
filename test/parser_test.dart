import 'package:flutter_test/flutter_test.dart';
import 'package:appletvbox/core/live_parser.dart';
import 'package:appletvbox/models/tvbox_config.dart';

void main() {
  test('解析 TVBox config 站点与类型', () {
    final config = TvboxConfig.fromJson({
      'sites': [
        {'key': 'json1', 'name': 'JSON源', 'api': 'https://a.com/api.php/provide/vod'},
        {'key': 'xbpq1', 'name': 'XBPQ源', 'api': 'csp_XBPQ', 'ext': '{}'},
        {'key': 'jar1', 'name': 'JAR源', 'api': 'csp_Test', 'jar': 'https://a.com/x.jar'},
      ],
      'lives': [
        {
          'name': '直播',
          'channels': [
            {'name': '央视', 'urls': 'https://a.com/live.m3u'}
          ]
        }
      ],
    });
    expect(config.sites.length, 3);
    expect(config.sites[0].type, SiteType.json);
    expect(config.sites[1].type, SiteType.xbpq);
    expect(config.sites[2].supported, isFalse);
    expect(config.lives.length, 1);
  });

  test('解析 m3u 直播源', () {
    const content = '''
#EXTM3U
#EXTINF:-1 tvg-id="cctv1" group-title="央视",CCTV-1
http://a.com/cctv1.m3u8
#EXTINF:-1 group-title="央视",CCTV-2
http://a.com/cctv2.m3u8
''';
    final channels = M3uParser.parse(content);
    expect(channels.length, 2);
    expect(channels[0].name, 'CCTV-1');
    expect(channels[0].group, '央视');
  });

  test('解析直播 txt', () {
    const content = '央视,#genre#\nCCTV-1,http://a/1.m3u8';
    final channels = parseLiveTxt(content);
    expect(channels.length, 1);
    expect(channels[0].group, '央视');
  });
}
