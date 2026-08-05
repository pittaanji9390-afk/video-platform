import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

typedef VoiceCommandCallback = void Function(String command, String rawSpokenText);

class VoskVoiceCommandService {
  static final VoskVoiceCommandService _instance = VoskVoiceCommandService._internal();
  factory VoskVoiceCommandService() => _instance;
  VoskVoiceCommandService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;
  VoiceCommandCallback? _onCommandDetected;

  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;

  /// Initialize Vosk / Speech Recognition Engine
  Future<bool> initialize() async {
    try {
      _isAvailable = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Vosk Speech Status: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
          }
        },
        onError: (errorNotification) {
          debugPrint('Vosk Speech Error: ${errorNotification.errorMsg}');
          _isListening = false;
        },
      );
      return _isAvailable;
    } catch (e) {
      debugPrint('Vosk Speech init exception: $e');
      _isAvailable = false;
      return false;
    }
  }

  /// Start Listening for Voice Commands
  Future<void> startListening({
    required VoiceCommandCallback onCommand,
    String? languageTag,
  }) async {
    _onCommandDetected = onCommand;

    if (!_isAvailable) {
      final ready = await initialize();
      if (!ready) {
        debugPrint('Speech engine unavailable');
        return;
      }
    }

    if (_isListening) return;

    try {
      _isListening = true;
      await _speech.listen(
        onResult: (result) {
          final recognizedText = result.recognizedWords.toLowerCase().trim();
          if (recognizedText.isNotEmpty) {
            _processSpokenText(recognizedText);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: languageTag ?? 'en_US',
      );
    } catch (e) {
      debugPrint('Error starting speech listener: $e');
      _isListening = false;
    }
  }

  /// Stop Listening
  Future<void> stopListening() async {
    if (!_isListening) return;
    try {
      await _speech.stop();
      _isListening = false;
    } catch (e) {
      debugPrint('Error stopping speech listener: $e');
    }
  }

  /// Process Spoken Voice Text and map to actionable commands
  void _processSpokenText(String text) {
    String? detectedCommand;

    if (text.contains('start record') || text.contains('begin record') || text.contains('record video') || text == 'start') {
      detectedCommand = 'start_recording';
    } else if (text.contains('stop record') || text.contains('end record') || text.contains('stop video') || text == 'stop') {
      detectedCommand = 'stop_recording';
    } else if (text.contains('upload video') || text.contains('upload now') || text.contains('dispatch video') || text == 'upload') {
      detectedCommand = 'upload_video';
    } else if (text.contains('approve video') || text.contains('qc approve') || text.contains('pass video') || text == 'approve') {
      detectedCommand = 'qc_approve';
    } else if (text.contains('reject video') || text.contains('qc reject') || text.contains('fail video') || text == 'reject') {
      detectedCommand = 'qc_reject';
    } else if (text.contains('refresh') || text.contains('sync data') || text.contains('reload')) {
      detectedCommand = 'refresh_queue';
    }

    if (detectedCommand != null && _onCommandDetected != null) {
      _onCommandDetected!(detectedCommand, text);
    }
  }
}
