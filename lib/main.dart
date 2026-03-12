import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'screens/voice_translator_view.dart';
import 'screens/file_translator_view.dart';
import 'screens/text_scanner_view.dart';
import 'screens/doc_scanner_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ISA2 스마트 통역기',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: MainScreens(cameras: cameras),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreens extends StatefulWidget {
  final List<CameraDescription> cameras;
  const MainScreens({super.key, required this.cameras});

  @override
  State<MainScreens> createState() => _MainScreensState();
}

class _MainScreensState extends State<MainScreens> {
  int _currentIndex = 0;
  
  @override
  Widget build(BuildContext context) {
    Widget currentScreen;
    switch (_currentIndex) {
      case 0:
        currentScreen = DocScannerView(onHome: () => setState(() => _currentIndex = 0));
        break;
      case 1:
        currentScreen = TextScannerView(
          cameras: widget.cameras,
          onHome: () => setState(() => _currentIndex = 0),
        );
        break;
      case 2:
        currentScreen = const VoiceTranslatorView();
        break;
      case 3:
        currentScreen = FileTranslatorView(onHome: () => setState(() => _currentIndex = 0));
        break;
      default:
        currentScreen = const VoiceTranslatorView();
    }

    return Scaffold(
      body: currentScreen,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.document_scanner), label: '문서 원본'),
          BottomNavigationBarItem(icon: Icon(Icons.translate), label: '번역'),
          BottomNavigationBarItem(icon: Icon(Icons.mic), label: '음성 통역'),
          BottomNavigationBarItem(icon: Icon(Icons.description), label: '파일 번역'),
        ],
      ),
    );
  }
}
