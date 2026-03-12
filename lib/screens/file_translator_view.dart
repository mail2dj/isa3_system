import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';

class FileTranslatorView extends StatefulWidget {
  const FileTranslatorView({super.key});

  @override
  State<FileTranslatorView> createState() => _FileTranslatorViewState();
}

class _FileTranslatorViewState extends State<FileTranslatorView> {
  final TextEditingController _inputController = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();
  String _translatedText = "";
  bool _isProcessing = false;

  final Map<String, TranslateLanguage> _languages = {
    '한국어': TranslateLanguage.korean,
    '영어': TranslateLanguage.english,
    '일본어': TranslateLanguage.japanese,
    '중국어': TranslateLanguage.chinese,
  };
  
  String _targetLang = '영어';

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  void _initTts() {
    _flutterTts.setLanguage("ko-KR");
    _flutterTts.setPitch(1.1);
    _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _pickFile() async {
    try {
      // 1. 파일 선택 (확장자 제한을 일시적으로 풀어서 테스트)
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, // .txt만 선택할 때 가끔 안 눌리는 경우가 있어 전체 허용으로 변경
      );
  
      if (result != null && result.files.single.path != null) {
        String path = result.files.single.path!;
        // .txt 파일인지 간단히 확인
        if (!path.toLowerCase().endsWith('.txt')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("텍스트(.txt) 파일만 번역 가능합니다.")),
          );
          return;
        }

        File file = File(path);
        // UTF-8로 명시적 읽기 (한글 깨짐 방지)
        String content = await file.readAsString(encoding: utf8);
        
        setState(() {
          _inputController.text = content;
          _translatedText = "";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("파일을 성공적으로 불러왔습니다.")),
        );
      } else {
        // 선택 취소됨
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("파일 선택이 취소되었습니다.")),
        );
      }
    } catch (e) {
      debugPrint("파일 읽기 에러: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("파일을 불러오는 중 오류 발생: $e")),
      );
    }
  }

  Future<void> _translate() async {
    if (_inputController.text.isEmpty) return;
    setState(() => _isProcessing = true);
    try {
      final source = TranslateLanguage.korean;
      final target = _languages[_targetLang]!;
      
      // 모델 다운로드 체크
      final modelManager = OnDeviceTranslatorModelManager();
      await modelManager.downloadModel(source.bcpCode);
      await modelManager.downloadModel(target.bcpCode);

      final translator = OnDeviceTranslator(
        sourceLanguage: source,
        targetLanguage: target,
      );
      
      final result = await translator.translateText(_inputController.text);
      setState(() {
        _translatedText = result;
      });
      translator.close();
    } catch (e) {
      debugPrint("번역 에러: $e");
      setState(() {
        _translatedText = "번역 엔진 준비 중입니다. 잠시 후 다시 시도해 주세요.";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("번역 중 오류 발생: $e")),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _speak() async {
    String langCode = "en-US";
    if (_targetLang == '일본어') langCode = "ja-JP";
    if (_targetLang == '중국어') langCode = "zh-CN";
    if (_targetLang == '한국어') langCode = "ko-KR";
    
    await _flutterTts.setLanguage(langCode);
    await _flutterTts.speak(_translatedText);
  }

  void _copyResult() {
    Clipboard.setData(ClipboardData(text: _translatedText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("번역 결과가 클립보드에 복사되었습니다.")),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("문서 및 텍스트 번역기")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.file_open),
                    label: const Text("파일 열기"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _inputController.clear()),
                    icon: const Icon(Icons.clear_all),
                    label: const Text("지우기"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red[50]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("번역할 언어: "),
                DropdownButton<String>(
                  value: _targetLang,
                  onChanged: (v) => setState(() => _targetLang = v!),
                  items: _languages.keys.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                ),
              ],
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue[100]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _inputController,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: "여기에 직접 입력하거나 파일을 불러오세요",
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const Icon(Icons.arrow_downward, color: Colors.blue),
            Expanded(
              child: Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text("🌐 번역 결과:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        const Divider(),
                        _isProcessing 
                          ? const Center(child: CircularProgressIndicator()) 
                          : SelectableText(_translatedText.isEmpty ? "번역 결과가 여기에 표시됩니다" : _translatedText),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isProcessing ? null : _translate,
                  child: const Text("번역 시작"),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up, color: Colors.green),
                  onPressed: _translatedText.isEmpty ? null : _speak,
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.grey),
                  onPressed: _translatedText.isEmpty ? null : _copyResult,
                ),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.blue),
                  onPressed: _translatedText.isEmpty ? null : () => Share.share(_translatedText),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
