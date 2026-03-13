import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceTranslatorView extends StatefulWidget {
  const VoiceTranslatorView({super.key});

  @override
  State<VoiceTranslatorView> createState() => _VoiceTranslatorViewState();
}

class _VoiceTranslatorViewState extends State<VoiceTranslatorView> {
  final TextEditingController _inputController = TextEditingController();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  String _recognizedText = "";
  String _translatedText = "";
  bool _isListening = false;
  bool _isProcessing = false;
  bool _isPlaying = false;
  double _confidence = 0.0;
  bool _isStopping = false;

  final Map<String, TranslateLanguage> _mlKitLanguages = {
    '한국어': TranslateLanguage.korean,
    '영어': TranslateLanguage.english,
    '일본어': TranslateLanguage.japanese,
    '중국어': TranslateLanguage.chinese,
  };

  final Map<String, String> _speechLanguages = {
    '한국어': 'ko-KR',
    '영어': 'en-US',
    '일본어': 'ja-JP',
    '중국어': 'zh-CN',
  };

  late String _sourceLanguage = '한국어';
  late String _targetLanguage = '영어';

  @override
  void initState() {
    super.initState();
    _initTts();
    _initSpeech();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("ko-KR");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    });
  }

  Future<void> _initSpeech() async {
    try {
      bool available = await _speechToText.initialize(
        onError: (error) {
          debugPrint('Speech Error: $error');
          if (mounted && _isListening) {
            setState(() {
              _isListening = false;
              _isStopping = false;
            });
          }
        },
        onStatus: (status) {
          debugPrint('Speech Status: $status');
          // done 상태가 되면 자동 재시작 (더 긴 딜레이)
          if (status == 'done' && _isListening && !_isStopping && mounted) {
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (_isListening && !_isStopping && mounted) {
                _restartListening();
              }
            });
          }
        },
      );
      if (!available) {
        debugPrint('Speech recognition not available');
      }
    } catch (e) {
      debugPrint('Error initializing speech recognition: $e');
    }
  }

  Future<void> _restartListening() async {
    if (!_isListening || _isStopping || !mounted) return;

    try {
      await _speechToText.stop();
      await Future.delayed(const Duration(milliseconds: 600)); // 1500 → 600ms

      if (!_isListening || _isStopping || !mounted) return;

      // 🆕 이전 텍스트는 유지, UI만 초기화
      if (mounted) {
        setState(() {
          _confidence = 0.0;
        });
      }

      await _speechToText.listen(
        onResult: (result) {
          if (!mounted || !_isListening) return;

          setState(() {
            if (result.recognizedWords.isNotEmpty) {
              if (result.finalResult) {
                // 최종 결과만 누적
                _recognizedText = _recognizedText.isEmpty
                    ? result.recognizedWords
                    : "$_recognizedText ${result.recognizedWords}";
              } else {
                _confidence = result.confidence;
              }
            }
          });
        },
        localeId: _speechLanguages[_sourceLanguage],
      );
    } catch (e) {
      debugPrint('Error restarting listening: $e');
      if (mounted) {
        setState(() {
          _isListening = false;
          _isStopping = false;
        });
      }
    }
  }

  Future<void> _startListening() async {
    if (_isListening || _isProcessing || _isStopping) return;

    setState(() {
      _isListening = true;
      _recognizedText = "";
      _confidence = 0.0;
    });

    try {
      await _speechToText.listen(
        onResult: (result) {
          if (!mounted || !_isListening) return;

          setState(() {
            if (result.recognizedWords.isNotEmpty) {
              _recognizedText = result.recognizedWords;
              _confidence = result.confidence;
            }
            debugPrint(
              'Recognized: $_recognizedText, Final: ${result.finalResult}',
            );
          });
        },
        localeId: _speechLanguages[_sourceLanguage],
      );
    } catch (e) {
      debugPrint('Error starting listening: $e');
      if (mounted) {
        setState(() {
          _isListening = false;
          _isStopping = false;
        });
      }
    }
  }

  Future<void> _stopListening() async {
    if (!_isListening || _isStopping) return;

    setState(() => _isStopping = true);

    try {
      await _speechToText.stop();

      if (mounted) {
        setState(() {
          _isListening = false;
          _isStopping = false;
          if (_recognizedText.isNotEmpty) {
            _inputController.text = _recognizedText.trim();
          }
        });
      }
    } catch (e) {
      debugPrint('Error stopping listening: $e');
      if (mounted) {
        setState(() {
          _isListening = false;
          _isStopping = false;
        });
      }
    }
  }

  Future<void> _translate() async {
    if (_inputController.text.trim().isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      final source = _mlKitLanguages[_sourceLanguage]!;
      final target = _mlKitLanguages[_targetLanguage]!;

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
      if (mounted) {
        setState(() {
          _translatedText = result;
        });
      }
      translator.close();
    } catch (e) {
      debugPrint("번역 에러: $e");
      if (mounted) {
        setState(() {
          _translatedText = "번역 중 오류 발생: $e";
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _speak(String text, {bool isOriginal = false}) async {
    if (text.isEmpty) return;

    String langCode = "ko-KR";

    if (!isOriginal) {
      if (_targetLanguage == '영어') {
        langCode = "en-US";
      } else if (_targetLanguage == '일본어') {
        langCode = "ja-JP";
      } else if (_targetLanguage == '중국어') {
        langCode = "zh-CN";
      } else if (_targetLanguage == '한국어') {
        langCode = "ko-KR";
      }
    } else {
      if (_sourceLanguage == '영어') {
        langCode = "en-US";
      } else if (_sourceLanguage == '일본어') {
        langCode = "ja-JP";
      } else if (_sourceLanguage == '중국어') {
        langCode = "zh-CN";
      } else if (_sourceLanguage == '한국어') {
        langCode = "ko-KR";
      }
    }

    await _flutterTts.setLanguage(langCode);
    if (mounted) {
      setState(() => _isPlaying = true);
    }
    await _flutterTts.speak(text);
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("클립보드에 복사되었습니다.")));
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _speechToText.stop();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "음성 통역",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sourceLanguage,
                dropdownColor: Colors.blueAccent,
                icon: const Icon(Icons.language, color: Colors.white),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                onChanged: (String? newValue) {
                  if (newValue != null && !_isListening) {
                    setState(() => _sourceLanguage = newValue);
                  }
                },
                items: _mlKitLanguages.keys.map<DropdownMenuItem<String>>((
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
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: Colors.blueAccent.withValues(alpha: 0.2),
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  TextField(
                    controller: _inputController,
                    maxLines: null,
                    enabled: !_isListening,
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: "원본 텍스트를 입력하거나 마이크 버튼으로 음성 인식",
                      border: InputBorder.none,
                    ),
                    onChanged: (_) {
                      if (_translatedText.isNotEmpty) {
                        setState(() => _translatedText = "");
                      }
                    },
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: _inputController.text.isNotEmpty && !_isListening
                        ? IconButton(
                            icon: Icon(
                              _isPlaying ? Icons.volume_off : Icons.volume_up,
                              color: Colors.blueAccent,
                              size: 28,
                            ),
                            onPressed: () =>
                                _speak(_inputController.text, isOriginal: true),
                            tooltip: "원본 음성 재생",
                          )
                        : const SizedBox(),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isStopping)
                        ? null
                        : (_isListening ? _stopListening : _startListening),
                    icon: Icon(
                      _isStopping
                          ? Icons.hourglass_empty
                          : (_isListening ? Icons.mic_off : Icons.mic),
                    ),
                    label: Text(
                      _isStopping
                          ? "중지 중..."
                          : (_isListening ? "음성 인식 중지" : "음성 인식 시작"),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isStopping
                          ? Colors.grey
                          : (_isListening
                                ? Colors.redAccent
                                : Colors.blueAccent),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (!_isListening && !_isStopping)
                        ? () => setState(() {
                            _inputController.clear();
                            _translatedText = "";
                            _recognizedText = "";
                            _confidence = 0.0;
                          })
                        : null,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text("내용 지우기"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: (_isListening || _isStopping)
                          ? Colors.grey
                          : Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(
                        color: (_isListening || _isStopping)
                            ? Colors.grey
                            : Colors.redAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isListening)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Column(
                children: [
                  Text(
                    "인식 중... (신뢰도: ${(_confidence * 100).toStringAsFixed(1)}%)",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      value: _confidence > 0 ? _confidence : null,
                      strokeWidth: 3,
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
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
                      onChanged: _isListening
                          ? null
                          : (String? newValue) {
                              if (newValue != null) {
                                setState(() => _targetLanguage = newValue);
                                if (_inputController.text.isNotEmpty) {
                                  _translate();
                                }
                              }
                            },
                      items: _mlKitLanguages.keys.map<DropdownMenuItem<String>>(
                        (String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        },
                      ).toList(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.translate, color: Colors.green),
                      onPressed: _isListening ? null : _translate,
                      tooltip: "지금 번역하기",
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  if (_isProcessing)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    )
                  else if (_translatedText.isNotEmpty) ...[
                    _buildResultCard(
                      "🌐 번역 결과 ($_targetLanguage)",
                      _translatedText,
                      Colors.green,
                      isOriginal: false,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_inputController.text.isNotEmpty) ...[
                    _buildResultCard(
                      "📄 입력된 원어 ($_sourceLanguage)",
                      _inputController.text,
                      Colors.blueAccent,
                      isOriginal: true,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_inputController.text.isEmpty && !_isProcessing) ...[
                    const SizedBox(height: 40),
                    Icon(Icons.mic, size: 60, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      "마이크 버튼을 눌러 음성 인식을 시작하세요.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ],
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
                onPressed: (_isProcessing || _isListening) ? null : _translate,
                icon: const Icon(Icons.translate),
                label: const Text(
                  "번역 시작하기",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
