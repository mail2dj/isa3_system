import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';

class FileTranslatorView extends StatefulWidget {
  final VoidCallback? onHome;
  const FileTranslatorView({super.key, this.onHome});

  @override
  State<FileTranslatorView> createState() => _FileTranslatorViewState();
}

class _FileTranslatorViewState extends State<FileTranslatorView> {
  final TextEditingController _inputController = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();
  String _translatedText = "";
  bool _isProcessing = false;

  final Map<String, String> _sourceLanguages = {
    '한국어': 'ko',
    '영어': 'en',
    '일본어': 'ja',
    '중국어': 'zh-cn',
  };
  
  final Map<String, TranslateLanguage> _mlKitLanguages = {
    '영어': TranslateLanguage.english,
    '일본어': TranslateLanguage.japanese,
    '중국어': TranslateLanguage.chinese,
    '한국어': TranslateLanguage.korean,
  };
  
  String _selectedSourceLang = '한국어';
  String _targetLang = '영어';

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("ko-KR");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );
  
      if (result != null && result.files.single.path != null) {
        String path = result.files.single.path!;
        if (!path.toLowerCase().endsWith('.txt')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("텍스트(.txt) 파일만 번역 가능합니다.")),
          );
          return;
        }

        File file = File(path);
        String content = await file.readAsString(encoding: utf8);
        
        setState(() {
          _inputController.text = content;
          _translatedText = "";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("파일을 성공적으로 불러왔습니다.")),
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
    if (_inputController.text.trim().isEmpty) return;
    setState(() => _isProcessing = true);
    try {
      final source = _mlKitLanguages[_selectedSourceLang]!;
      final target = _mlKitLanguages[_targetLang]!;
      
      // 소스 언어와 대상 언어가 같으면 번역 건너뛰기
      if (source == target) {
        setState(() {
          _translatedText = "";
          _isProcessing = false;
        });
        return;
      }

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
        _translatedText = "번역 중 오류 발생: $e";
      });
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _speak(String text, {bool isOriginal = false}) async {
    if (text.isEmpty) return;

    String langCode = "ko-KR"; // 기본은 한국어

    if (!isOriginal) {
      // 번역 결과를 읽을 때 대상 언어에 맞게 설정
      if (_targetLang == '영어') langCode = "en-US";
      else if (_targetLang == '일본어') langCode = "ja-JP";
      else if (_targetLang == '중국어') langCode = "zh-CN";
      else if (_targetLang == '한국어') langCode = "ko-KR";
    } else {
      // 원문 텍스트는 선택된 소스 언어 기준
      if (_selectedSourceLang == '영어') langCode = "en-US";
      else if (_selectedSourceLang == '일본어') langCode = "ja-JP";
      else if (_selectedSourceLang == '중국어') langCode = "zh-CN";
      else if (_selectedSourceLang == '한국어') langCode = "ko-KR";
    }
    
    await _flutterTts.setLanguage(langCode);
    await _flutterTts.speak(text);
  }

  void _copyResult() {
    if (_translatedText.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _translatedText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("번역 결과가 클립보드에 복사되었습니다.")),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("파일 및 텍스트 번역", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
        elevation: 0,
        leading: widget.onHome != null 
          ? IconButton(
              icon: const Icon(Icons.home, color: Colors.white),
              onPressed: widget.onHome,
            )
          : null,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSourceLang,
                dropdownColor: Colors.blueAccent,
                icon: const Icon(Icons.language, color: Colors.white),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedSourceLang = newValue;
                    });
                  }
                },
                items: _sourceLanguages.keys.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.file_open),
                    label: const Text("파일 불러오기"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _inputController.clear();
                      _translatedText = "";
                    }),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text("내용 지우기"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
              ),
              child: TextField(
                controller: _inputController,
                maxLines: null,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  hintText: "여기에 번역할 내용을 입력하거나\n상단의 '파일 불러오기'를 이용해 주세요.",
                  border: InputBorder.none,
                ),
                onChanged: (_) {
                  // 타이핑 시에는 즉시 번역하지 않고 결과만 초기화하거나 버튼 유도
                  if (_translatedText.isNotEmpty) {
                    setState(() => _translatedText = "");
                  }
                },
              ),
            ),
          ),
          // 대상 언어 선택바 (항상 노출하여 사용자 편의성 증대)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("번역할 대상 언어 선택:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                Row(
                  children: [
                    DropdownButton<String>(
                      value: _targetLang,
                      dropdownColor: Colors.white,
                      underline: const SizedBox(),
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _targetLang = newValue;
                          });
                          if (_inputController.text.isNotEmpty) {
                            _translate();
                          }
                        }
                      },
                      items: _mlKitLanguages.keys.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.translate, color: Colors.green),
                      onPressed: _translate,
                      tooltip: "지금 번역하기",
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  if (_isProcessing)
                    const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                  else if (_translatedText.isNotEmpty) ...[
                    _buildResultCard("🌐 번역 결과 ($_targetLang)", _translatedText, Colors.green, isOriginal: false),
                    const SizedBox(height: 16),
                  ],
                  if (_inputController.text.isNotEmpty) ...[
                    _buildResultCard("📄 입력된 원어 ($_selectedSourceLang)", _inputController.text, Colors.blueAccent, isOriginal: true),
                    const SizedBox(height: 16),
                  ],
                  if (_inputController.text.isEmpty && !_isProcessing) ...[
                    const SizedBox(height: 40),
                    Icon(Icons.text_fields, size: 60, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text("번역할 내용을 입력하거나 파일을 불러와 주세요.", 
                      textAlign: TextAlign.center, 
                      style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                  ]
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _translate,
                icon: const Icon(Icons.translate),
                label: const Text("번역 시작하기", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildResultCard(String title, String content, Color titleColor, {required bool isOriginal}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: titleColor.withOpacity(0.3), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: titleColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: titleColor, fontSize: 16)),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.volume_up, size: 22, color: titleColor), 
                      onPressed: () => _speak(content, isOriginal: isOriginal),
                      tooltip: "읽어주기",
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 22, color: Colors.grey), 
                      onPressed: () => _copyResultContent(content),
                      tooltip: "복사하기",
                    ),
                  ],
                )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SelectableText(content, style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  void _copyResultContent(String text) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("클립보드에 복사되었습니다.")),
    );
  }
}
