import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:share_plus/share_plus.dart';
import 'package:translator/translator.dart';
import 'package:flutter_tts/flutter_tts.dart';

class DocScannerView extends StatefulWidget {
  final VoidCallback? onHome;
  const DocScannerView({super.key, this.onHome});

  @override
  State<DocScannerView> createState() => _DocScannerViewState();
}

class _DocScannerViewState extends State<DocScannerView> {
  DocumentScanner? _documentScanner;
  DocumentScanningResult? _result;
  
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.korean);
  final GoogleTranslator _translator = GoogleTranslator();
  final FlutterTts _flutterTts = FlutterTts();

  String _extractedText = "";
  String _translatedText = "";
  bool _isProcessing = false;

  final Map<String, String> _translateLanguages = {
    '한국어': 'ko',
    '영어': 'en',
    '일본어': 'ja',
    '중국어': 'zh-cn',
  };
  String _targetLanguage = '한국어';

  @override
  void initState() {
    super.initState();
    _initScanner();
    _initTts();
  }

  void _initScanner() {
    _documentScanner = DocumentScanner(
      options: DocumentScannerOptions(
        mode: ScannerMode.full,
        isGalleryImport: false,
        pageLimit: 1,
      ),
    );
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("ko-KR");
    await _flutterTts.setSpeechRate(0.5);
  }

  @override
  void dispose() {
    _documentScanner?.close();
    _textRecognizer.close();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _startScan() async {
    try {
      final result = await _documentScanner?.scanDocument();
      setState(() {
        _result = result;
        _extractedText = "";
        _translatedText = "";
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("스캔 중 에러 발생: $e")),
        );
      }
    }
  }

  Future<void> _translate(String text) async {
    if (text.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _translatedText = "번역 중...";
    });

    try {
      final targetCode = _translateLanguages[_targetLanguage]!;
      final translation = await _translator.translate(text, to: targetCode);
      
      setState(() {
        _translatedText = translation.text;
      });
    } catch (e) {
      debugPrint("번역 에러: $e");
      setState(() {
        _translatedText = "번역 중 오류가 발생했습니다.";
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processOcrAndTranslate() async {
    if (_result == null || _result!.images == null || _result!.images!.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // 1. OCR (텍스트 추출)
      final inputImage = InputImage.fromFilePath(_result!.images!.first);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      String cleanText = recognizedText.text.replaceAll('\n', ' ').trim();
      
      setState(() {
        _extractedText = cleanText;
      });

      // 2. 번역 (선택된 대상 언어로)
      if (cleanText.isNotEmpty) {
        await _translate(cleanText);
      }

    } catch (e) {
      debugPrint("OCR 에러: $e");
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _speak(String text, {bool isOriginal = false}) async {
    if (text.isEmpty) return;

    String langCode = "ko-KR"; // 기본은 한국어

    if (!isOriginal) {
      // 번역본을 읽을 때는 대상 언어에 맞게 설정
      if (_targetLanguage == '영어') langCode = "en-US";
      else if (_targetLanguage == '일본어') langCode = "ja-JP";
      else if (_targetLanguage == '중국어') langCode = "zh-CN";
      else if (_targetLanguage == '한국어') langCode = "ko-KR";
    } else {
      // 원본 텍스트는 우선 한국어로 설정 (혹은 감지된 언어에 따라 설정 가능하나 여기선 한국어 고정/공통)
      langCode = "ko-KR"; 
    }

    await _flutterTts.setLanguage(langCode);
    await _flutterTts.speak(text);
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("복사되었습니다.")));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("문서 원본 & 번역", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
          if (_result != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () => setState(() {
                _result = null;
                _extractedText = "";
                _translatedText = "";
              }),
            )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (_result == null) ...[
              const SizedBox(height: 80),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.document_scanner, size: 100, color: Colors.blueAccent),
              ),
              const SizedBox(height: 32),
              const Text("문서 원본 스캐너", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 16),
              const Text("문서를 스캔하여 글자를 추출하고\n번역과 음성 서비스를 이용해 보세요.", 
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: _startScan,
                icon: const Icon(Icons.camera_alt, size: 28),
                label: const Text("문서 스캔 시작하기", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 5,
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                            ),
                            child: Image.file(File(_result!.images!.first), height: 300, width: double.infinity, fit: BoxFit.cover),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: FloatingActionButton.small(
                            onPressed: _startScan,
                            backgroundColor: Colors.blueAccent,
                            child: const Icon(Icons.camera_alt, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    if (_extractedText.isEmpty && !_isProcessing)
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton.icon(
                          onPressed: _processOcrAndTranslate,
                          icon: const Icon(Icons.translate, size: 24),
                          label: const Text("텍스트 추출 및 번역하기", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                          ),
                        ),
                      ),

                    if (_isProcessing)
                      const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(),
                      ),

                    if (_extractedText.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildResultCard("📄 원본 텍스트 (추출 완료)", _extractedText, Colors.blueAccent, isOriginal: true),
                      const SizedBox(height: 16),
                      // 대상 언어 선택바
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                  value: _targetLanguage,
                                  dropdownColor: Colors.white,
                                  underline: const SizedBox(),
                                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _targetLanguage = newValue;
                                      });
                                      _translate(_extractedText);
                                    }
                                  },
                                  items: _translateLanguages.keys.map<DropdownMenuItem<String>>((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  }).toList(),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.translate, color: Colors.green),
                                  onPressed: () => _translate(_extractedText),
                                  tooltip: "지금 번역하기",
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_translatedText.isNotEmpty) 
                        _buildResultCard("🌐 번역 결과 ($_targetLanguage)", _translatedText, Colors.green, isOriginal: false),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _copy(_translatedText.isNotEmpty ? _translatedText : _extractedText),
                              icon: const Icon(Icons.copy),
                              label: const Text("전체 복사", style: TextStyle(fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blueAccent,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: Colors.blueAccent, width: 2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => Share.share(_translatedText.isNotEmpty ? _translatedText : _extractedText),
                              icon: const Icon(Icons.share),
                              label: const Text("결과 공유", style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ]
                  ],
                ),
              ),
            ],
            const SizedBox(height: 100),
          ],
        ),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                      onPressed: () => _copy(content),
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
}
