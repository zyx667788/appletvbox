import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'features/home/home_page.dart';
import 'features/live/live_page.dart';
import 'features/settings/settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const AppletvboxApp());
}

class AppletvboxApp extends StatelessWidget {
  const AppletvboxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TVBox',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE50914),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const RootShell(),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  final _pages = const [HomePage(), LivePage(), SettingsPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.movie_outlined), label: '影视'),
          NavigationDestination(
              icon: Icon(Icons.live_tv_outlined), label: '直播'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined), label: '设置'),
        ],
      ),
    );
  }
}
