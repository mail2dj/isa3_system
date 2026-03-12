import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:share_plus/share_plus.dart';

class VoiceTranslatorView extends StatefulWidget {
  const VoiceTranslatorView({super.key});

  @override
  State<VoiceTranslatorView> createState() => _VoiceTranslatorViewState();
}

class _VoiceTranslatorViewState extends State<VoiceTranslatorView> {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  
  bool _speechEnabled = false;
  String _wordsSpoken = "";
  String _translatedText = "";
  bool _isProcessing = false;
  bool _isButtonPressed = false;

  final Map<String, TranslateLanguage> _languages = {
    '한국어': TranslateLanguage.korean,
    '영어': TranslateLanguage.english,
    '일본어': TranslateLanguage.japanese,
    '중국어': TranslateLanguage.chinese,
  };
  
  String _sourceLang = '한국어';
  String _targetLang = '영어';

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize(
      onError: (val) {
        debugPrint('음성 인식 에러: $val');
        setState(() => _isButtonPressed = false);
      },
      onStatus: (status) {
        debugPrint('음성 인식 상태: $status');
        // UI 상태인 _isButtonPressed는 실제 물리적인 터치 업(onPointerUp)에서만 변경하도록 하여
        // 엔진이 잠시 멈추더라도 버튼이 파란색으로 변하는 것을 방지합니다.
      },
    );
    setState(() {});
  }

  void _initTts() {
    _flutterTts.setLanguage("ko-KR");
    _flutterTts.setPitch(1.1);
    _flutterTts.setSpeechRate(0.5);
  }

  void _startListening() async {
    if (!_speechEnabled) return;
    setState(() => _isButtonPressed = true);
    try {
      await _speechToText.listen(
        onResult: (result) {
          setState(() {
            _wordsSpoken = result.recognizedWords;
          });
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 10),
        listenMode: ListenMode.dictation,
        onDevice: true,
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('음성 인식 시작 에러: $e');
      setState(() => _isButtonPressed = false);
    }
  }

  void _stopListening() async {
    setState(() => _isButtonPressed = false);
    await _speechToText.stop();
    setState(() {});
  }

  Future<void> _translate() async {
    if (_wordsSpoken.isEmpty) return;
    setState(() => _isProcessing = true);
    try {
      final source = _languages[_sourceLang]!;
      final target = _languages[_targetLang]!;
      
      final modelManager = OnDeviceTranslatorModelManager();
      // Ensure models are downloaded before translating
      await modelManager.downloadModel(source.bcpCode);
      await modelManager.downloadModel(target.bcpCode);

      final translator = OnDeviceTranslator(
        sourceLanguage: source,
        targetLanguage: target,
      );
      
      final result = await translator.translateText(_wordsSpoken);
      setState(() {
        _translatedText = result;
      });
      translator.close();
    } catch (e) {
      debugPrint("번역 에러: $e");
      setState(() {
        _translatedText = "번역 엔진 준비 중입니다. 잠시 후 다시 시도해 주세요.";
      });
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

  Future<void> _speakOriginal() async {
    String langCode = "ko-KR";
    if (_sourceLang == '영어') langCode = "en-US";
    if (_sourceLang == '일본어') langCode = "ja-JP";
    if (_sourceLang == '중국어') langCode = "zh-CN";
    
    await _flutterTts.setLanguage(langCode);
    await _flutterTts.speak(_wordsSpoken);
  }

  void _copyOriginal() {
    Clipboard.setData(ClipboardData(text: _wordsSpoken));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("인식된 음성이 클립보드에 복사되었습니다.")),
    );
  }

  void _copyResult() {
    Clipboard.setData(ClipboardData(text: _translatedText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("번역 결과가 클립보드에 복사되었습니다.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("음성 통역기 (STT/TTS)")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DropdownButton<String>(
                  value: _sourceLang,
                  onChanged: (v) {
                    setState(() => _sourceLang = v!);
                    if (_wordsSpoken.isNotEmpty) _translate();
                  },
                  items: _languages.keys.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                ),
                const Icon(Icons.arrow_forward),
                DropdownButton<String>(
                  value: _targetLang,
                  onChanged: (v) {
                    setState(() => _targetLang = v!);
                    if (_wordsSpoken.isNotEmpty) _translate();
                  },
                  items: _languages.keys.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("🎙️ 인식된 음성:", style: TextStyle(fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.volume_up, size: 20, color: Colors.blueGrey),
                                onPressed: _wordsSpoken.isEmpty ? null : _speakOriginal,
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 18, color: Colors.blueGrey),
                                onPressed: _wordsSpoken.isEmpty ? null : _copyOriginal,
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(_wordsSpoken.isEmpty ? "마이크 버튼을 누르고 말씀하세요" : _wordsSpoken, style: const TextStyle(fontSize: 18)),
                      if (_wordsSpoken.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.translate),
                                label: const Text("번역하기"),
                                onPressed: _isProcessing ? null : _translate,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.grey),
                              onPressed: () {
                                setState(() {
                                  _wordsSpoken = "";
                                  _translatedText = "";
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                      const Divider(height: 40),
                      const Text("🌐 번역 결과:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      _isProcessing ? const Center(child: CircularProgressIndicator()) : SelectableText(_translatedText, style: const TextStyle(fontSize: 20, color: Colors.blue)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.volume_up, size: 40, color: Colors.green),
                  onPressed: _translatedText.isEmpty ? null : _speak,
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 30, color: Colors.grey),
                  onPressed: _translatedText.isEmpty ? null : _copyResult,
                ),
                IconButton(
                  icon: const Icon(Icons.share, size: 30, color: Colors.blue),
                  onPressed: _translatedText.isEmpty ? null : () => Share.share(_translatedText),
                ),
              ],
            )
          ],
        ),
      ),
      floatingActionButton: Listener(
        onPointerDown: (_) => _startListening(),
        onPointerUp: (_) => _stopListening(),
        onPointerCancel: (_) => _stopListening(),
        child: SizedBox(
          width: 100,
          height: 100,
          child: FloatingActionButton(
            onPressed: () {}, // Handled by Listener
            backgroundColor: _isButtonPressed ? Colors.red : Colors.blue,
            child: Icon(_isButtonPressed ? Icons.mic : Icons.mic_none, size: 44),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
