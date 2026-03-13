import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TextScannerView extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String selectedLanguage;
  final Function(String)? onLanguageChanged;
  final VoidCallback? onHome;
  const TextScannerView({
    super.key,
    required this.cameras,
    this.selectedLanguage = '영어',
    this.onLanguageChanged,
    this.onHome,
  });

  @override
  TextScannerViewState createState() => TextScannerViewState();
}

class TextScannerViewState extends State<TextScannerView> {
  late CameraController _controller;
  final FlutterTts _flutterTts = FlutterTts();

  String _originalText = "종이를 비추고 스캔하기 버튼을 눌러주세요!";
  String _translatedText = "";
  bool _isProcessing = false;

  final Map<String, TranslateLanguage> _translateLanguages = {
    '한국어': TranslateLanguage.korean,
    '영어': TranslateLanguage.english,
    '일본어': TranslateLanguage.japanese,
    '중국어': TranslateLanguage.chinese,
  };

  String _targetLanguage = '한국어';

  final Map<String, TextRecognitionScript> _supportedLanguages = {
    '영어': TextRecognitionScript.latin,
    '일본어': TextRecognitionScript.japanese,
    '중국어': TextRecognitionScript.chinese,
    '한국어': TextRecognitionScript.korean,
  };

  late String _selectedLanguage;
  late TextRecognizer _textRecognizer;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.selectedLanguage;
    _initRecognizer();
    _initTts();
    _controller = CameraController(widget.cameras[0], ResolutionPreset.high);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  void _initRecognizer() {
    _textRecognizer = TextRecognizer(
      script: _supportedLanguages[_selectedLanguage]!,
    );
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("ko-KR");
    await _flutterTts.setSpeechRate(0.5);
  }

  void _onLanguageChanged(String? newValue) {
    if (newValue != null && newValue != _selectedLanguage) {
      setState(() {
        _selectedLanguage = newValue;
      });
      widget.onLanguageChanged?.call(newValue);
      _textRecognizer.close();
      _initRecognizer();

      bool isResultValid =
          _originalText != "종이를 비추고 스캔하기 버튼을 눌러주세요!" &&
          _originalText != "인식 중..." &&
          _originalText != "글자를 찾지 못했습니다." &&
          !_originalText.startsWith("에러 발생:");

      if (isResultValid) {
        _translate(_originalText);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _textRecognizer.close();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _translate(String text) async {
    if (text.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _translatedText = "번역 중...";
    });

    try {
      TranslateLanguage sourceLang = TranslateLanguage.english;
      TranslateLanguage targetLang = _translateLanguages[_targetLanguage]!;

      if (_selectedLanguage == '일본어') {
        sourceLang = TranslateLanguage.japanese;
      } else if (_selectedLanguage == '중국어') {
        sourceLang = TranslateLanguage.chinese;
      } else if (_selectedLanguage == '한국어') {
        sourceLang = TranslateLanguage.korean;
      }

      if (sourceLang == targetLang) {
        setState(() {
          _translatedText = "";
          _isProcessing = false;
        });
        return;
      }

      final translator = OnDeviceTranslator(
        sourceLanguage: sourceLang,
        targetLanguage: targetLang,
      );

      String result = await translator.translateText(text);
      translator.close();

      setState(() {
        _translatedText = result;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _translatedText = "번역 중 오류 발생: $e";
        _isProcessing = false;
      });
    }
  }

  Future<void> _takeAndScan() async {
    if (!_controller.value.isInitialized ||
        _controller.value.isTakingPicture ||
        _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _originalText = "인식 중...";
      _translatedText = "";
    });

    try {
      final image = await _controller.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);

      final recognizedText = await _textRecognizer.processImage(inputImage);

      String extractedText = recognizedText.text.replaceAll('\n', ' ');
      extractedText = extractedText.replaceAll(RegExp(r'\s+'), ' ').trim();

      if (extractedText.isEmpty) {
        setState(() {
          _originalText = "글자를 찾지 못했습니다.";
          _isProcessing = false;
        });
        return;
      }

      setState(() {
        _originalText = extractedText;
      });

      await _translate(extractedText);
    } catch (e) {
      setState(() {
        _originalText = "에러 발생: $e";
        _translatedText = "";
        _isProcessing = false;
      });
    }
  }

  Future<void> _speak(String text, {bool isOriginal = false}) async {
    if (text.isEmpty) return;

    String langCode = "ko-KR";

    if (isOriginal) {
      if (_selectedLanguage == '영어') {
        langCode = "en-US";
      } else if (_selectedLanguage == '일본어') {
        langCode = "ja-JP";
      } else if (_selectedLanguage == '중국어') {
        langCode = "zh-CN";
      } else if (_selectedLanguage == '한국어') {
        langCode = "ko-KR";
      }
    } else {
      if (_targetLanguage == '한국어') {
        langCode = "ko-KR";
      } else if (_targetLanguage == '영어') {
        langCode = "en-US";
      } else if (_targetLanguage == '일본어') {
        langCode = "ja-JP";
      } else if (_targetLanguage == '중국어') {
        langCode = "zh-CN";
      }
    }

    await _flutterTts.setLanguage(langCode);
    await _flutterTts.speak(text);
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("클립보드에 복사되었습니다!"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    bool isResultValid =
        _originalText != "종이를 비추고 스캔하기 버튼을 눌러주세요!" &&
        _originalText != "인식 중..." &&
        _originalText != "글자를 찾지 못했습니다." &&
        !_originalText.startsWith("에러 발생:");

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "문자 번역 스캐너",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
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
                value: _selectedLanguage,
                dropdownColor: Colors.blueAccent,
                icon: const Icon(Icons.language, color: Colors.white),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                onChanged: _onLanguageChanged,
                items: _supportedLanguages.keys.map<DropdownMenuItem<String>>((
                  String value,
                ) {
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
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: CameraPreview(_controller),
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (isResultValid) ...[
                      const SizedBox(height: 16),
                      _buildResultCard(
                        "📄 추출된 원어 ($_selectedLanguage)",
                        _originalText,
                        Colors.blueAccent,
                        isOriginal: true,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "번역할 대상 언어 선택:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            Row(
                              children: [
                                DropdownButton<String>(
                                  value: _targetLanguage,
                                  dropdownColor: Colors.white,
                                  underline: const SizedBox(),
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _targetLanguage = newValue;
                                      });
                                      _translate(_originalText);
                                    }
                                  },
                                  items: _translateLanguages.keys
                                      .map<DropdownMenuItem<String>>((
                                        String value,
                                      ) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(value),
                                        );
                                      })
                                      .toList(),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.translate,
                                    color: Colors.green,
                                  ),
                                  onPressed: () => _translate(_originalText),
                                  tooltip: "지금 번역하기",
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_translatedText.isNotEmpty)
                        _buildResultCard(
                          "🌐 번역 결과 ($_targetLanguage)",
                          _translatedText,
                          Colors.green,
                          isOriginal: false,
                        ),
                      const SizedBox(height: 24),
                    ] else ...[
                      const SizedBox(height: 40),
                      Icon(Icons.camera_alt, size: 60, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        _originalText,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
      floatingActionButton: SizedBox(
        width: 160,
        height: 56,
        child: FloatingActionButton.extended(
          onPressed: _isProcessing ? null : _takeAndScan,
          backgroundColor: _isProcessing ? Colors.grey : Colors.blueAccent,
          icon: _isProcessing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.document_scanner),
          label: Text(
            _isProcessing ? "처리 중..." : "문자 스캔하기",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          elevation: 6,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildResultCard(
    String title,
    String content,
    Color titleColor, {
    required bool isOriginal,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: titleColor.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: titleColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                    fontSize: 16,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.volume_up, size: 22, color: titleColor),
                      onPressed: () => _speak(content, isOriginal: isOriginal),
                      tooltip: "읽어주기",
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.copy,
                        size: 22,
                        color: Colors.grey,
                      ),
                      onPressed: () => _copyToClipboard(content),
                      tooltip: "복사하기",
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SelectableText(
              content,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
