import 'package:flutter/material.dart';
import 'screens/voice_translator_view.dart';
import 'screens/file_translator_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ISA2 스마트 통역기',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainScreens(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreens extends StatefulWidget {
  const MainScreens({super.key});

  @override
  State<MainScreens> createState() => _MainScreensState();
}

class _MainScreensState extends State<MainScreens> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    const VoiceTranslatorView(),
    const FileTranslatorView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.mic), label: '음성 통역'),
          BottomNavigationBarItem(icon: Icon(Icons.description), label: '파일 번역'),
        ],
      ),
    );
  }
}
