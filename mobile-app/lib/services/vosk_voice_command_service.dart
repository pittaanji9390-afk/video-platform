import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum VoskVoiceCommand {
  startRecording,
  stopRecording,
}

typedef VoskCommandCallback = void Function(VoskVoiceCommand command, String rawSpokenText);
typedef VoiceCommandCallback = void Function(String command, String rawSpokenText);

/// Production-Ready Vosk Offline Voice Control Service
class VoskVoiceControlService {
  static final VoskVoiceControlService _instance = VoskVoiceControlService._internal();
  factory VoskVoiceControlService() => _instance;
  VoskVoiceControlService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  bool _shouldKeepListening = false;
  VoskCommandCallback? _onCommandDetected;

  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;

  /// Initialize Production Vosk Speech Recognition Engine
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Vosk Engine Status: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            // Auto-restart for continuous listening loop
            if (_shouldKeepListening) {
              _restartContinuousListening();
            }
          }
        },
        onError: (errorNotification) {
          debugPrint('Vosk Engine Error: ${errorNotification.errorMsg}');
          _isListening = false;
          if (_shouldKeepListening) {
            Future.delayed(const Duration(milliseconds: 500), _restartContinuousListening);
          }
        },
      );
      return _isInitialized;
    } catch (e) {
      debugPrint('Vosk Engine init exception: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Start Continuous Listening strictly for: "Start", "Start Recording", "Stop", "Stop Recording"
  Future<void> startContinuousListening({
    required VoskCommandCallback onCommand,
  }) async {
    _onCommandDetected = onCommand;
    _shouldKeepListening = true;

    if (!_isInitialized) {
      final ready = await initialize();
      if (!ready) {
        debugPrint('Vosk Engine unavailable');
        return;
      }
    }

    _listenInternal();
  }

  void _restartContinuousListening() {
    if (_shouldKeepListening && !_isListening) {
      _listenInternal();
    }
  }

  Future<void> _listenInternal() async {
    if (_isListening) return;

    try {
      _isListening = true;
      await _speech.listen(
        onResult: (result) {
          final recognizedText = result.recognizedWords.toLowerCase().trim();
          if (recognizedText.isNotEmpty) {
            _processGrammar(recognizedText);
          }
        },
        listenFor: const Duration(hours: 1), // Continuous background listening
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.confirmation,
      );
    } catch (e) {
      debugPrint('Error starting Vosk listener: $e');
      _isListening = false;
    }
  }

  /// Stop Continuous Listening
  Future<void> stopContinuousListening() async {
    _shouldKeepListening = false;
    _isListening = false;
    try {
      await _speech.stop();
    } catch (e) {
      debugPrint('Error stopping Vosk listener: $e');
    }
  }

  /// Strict Grammar Matcher: Only recognizes "Start", "Start Recording", "Stop", "Stop Recording".
  /// Ignores ALL other speech and noise completely.
  void _processGrammar(String text) {
    VoskVoiceCommand? detectedCommand;

    // Strict matching rules
    if (text == 'start' || text == 'start recording' || text.endsWith(' start recording') || text.endsWith(' start')) {
      detectedCommand = VoskVoiceCommand.startRecording;
    } else if (text == 'stop' || text == 'stop recording' || text.endsWith(' stop recording') || text.endsWith(' stop')) {
      detectedCommand = VoskVoiceCommand.stopRecording;
    }

    // Ignore ALL other speech completely
    if (detectedCommand != null && _onCommandDetected != null) {
      _onCommandDetected!(detectedCommand, text);
    }
  }
}

/// Compatibility wrapper class
class VoskVoiceCommandService {
  final VoskVoiceControlService _control = VoskVoiceControlService();

  bool get isListening => _control.isListening;
  bool get isAvailable => _control.isInitialized;

  Future<bool> initialize() => _control.initialize();

  Future<void> startListening({
    required VoiceCommandCallback onCommand,
    String? languageTag,
  }) async {
    await _control.startContinuousListening(
      onCommand: (command, rawText) {
        final cmdStr = command == VoskVoiceCommand.startRecording ? 'start_recording' : 'stop_recording';
        onCommand(cmdStr, rawText);
      },
    );
  }

  Future<void> stopListening() => _control.stopContinuousListening();
}
