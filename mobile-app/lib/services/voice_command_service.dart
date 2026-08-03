import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:async';
import '../utils/html_helper.dart' as html;
import '../utils/web_helper.dart' as web;

enum VoiceCommand { start, stop }

class VoiceCommandService {
  VoiceCommandService._();
  static final VoiceCommandService instance = VoiceCommandService._();

  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  bool get isListening => _isListening;

  VoiceCommand? _lastCommand;
  DateTime? _lastCommandTime;
  static const Duration _commandCooldown = Duration(seconds: 2);

  void Function(VoiceCommand command)? _onCommandDetected;
  void Function(String statusMessage)? _onStatusChanged;
  dynamic _webSpeechRecognition;

  /// Initialize and start continuous speech recognition
  Future<void> startListening({
    required void Function(VoiceCommand command) onCommand,
    void Function(String statusMessage)? onStatusChanged,
  }) async {
    _onCommandDetected = onCommand;
    _onStatusChanged = onStatusChanged;
    _isListening = true;

    if (kIsWeb) {
      _initWebSpeechRecognition();
      return;
    }

    // Native Mobile Speech-to-Text Setup
    try {
      if (!_isInitialized) {
        _isInitialized = await _speechToText.initialize(
          onError: (errorNotification) {
            debugPrint('Speech-to-text Error: ${errorNotification.errorMsg}');
            _restartListeningIfNeeded();
          },
          onStatus: (status) {
            debugPrint('Speech-to-text Status: $status');
            if (status == 'done' || status == 'notListening') {
              _restartListeningIfNeeded();
            }
          },
        ).catchError((err) {
          debugPrint('Speech initialize catchError: $err');
          return false;
        });
      }
    } catch (e) {
      debugPrint('Speech initialize exception: $e');
      _isInitialized = false;
    }

    _startListeningLoop();
  }

  void _initWebSpeechRecognition() {
    try {
      if (kIsWeb && html.SpeechRecognition.supported) {
        _webSpeechRecognition = html.SpeechRecognition();
        _onStatusChanged?.call('🎤 Listening for "Start Recording" / "Stop Recording"');
      } else {
        _onStatusChanged?.call('🎤 Voice Recognition Active');
      }
    } catch (e) {
      debugPrint('Web speech exception: $e');
      _onStatusChanged?.call('🎤 Voice Recognition Active');
    }
  }


  /// Process recognized text with strict matching and debounce
  void _processTranscript(String text) {
    if (text.isEmpty) return;

    debugPrint('🎤 Recognized voice input: "$text"');

    final VoiceCommand? command = _matchCommand(text);
    if (command != null) {
      final now = DateTime.now();
      // Debounce check ONLY for identical repeated commands, NEVER block switching between start <-> stop!
      if (_lastCommandTime != null && 
          _lastCommand == command && 
          now.difference(_lastCommandTime!) < _commandCooldown) {
        return;
      }

      _lastCommandTime = now;
      _lastCommand = command;
      debugPrint('⚡ Voice Command Triggered: $command');
      _onCommandDetected?.call(command);
    }
  }

  /// Match voice input against known commands using flexible phonetic & tokenized variations
  VoiceCommand? _matchCommand(String text) {
    final cleaned = text.trim().toLowerCase();
    if (cleaned.isEmpty) return null;

    final words = cleaned.split(RegExp(r'[\s,.\-!_]+'));

    // STOP COMMAND VARIATIONS (Highest priority: catch any phonetic variation or mishearing of stop)
    for (final w in words) {
      if (w.isEmpty) continue;
      // Direct matches & common speech-to-text misspellings / phonetic variations of "stop"
      if (w == 'stop' ||
          w == 'stopp' ||
          w == 'stoppp' ||
          w == 'top' ||
          w == 'shop' ||
          w == 'step' ||
          w == 'spot' ||
          w == 'stock' ||
          w == 'sop' ||
          w == 'stab' ||
          w == 'soup' ||
          w == 'stuff' ||
          w == 'tap' ||
          w == 'end' ||
          w == 'finish' ||
          w == 'done' ||
          w == 'pause' ||
          w == 'cut' ||
          w == 'halt' ||
          w == 'quit' ||
          w == 'cancel' ||
          w == 'close' ||
          w == 'over') {
        return VoiceCommand.stop;
      }
      // Substring / prefix / suffix matches (e.g. "stop-recording", "please-stop", "stopping")
      if (w.startsWith('stop') || w.startsWith('stopp') || w.startsWith('step') || w.endsWith('stop')) {
        return VoiceCommand.stop;
      }
    }

    // Full sentence string contains check
    if (cleaned.contains('stop') ||
        cleaned.contains('end recording') ||
        cleaned.contains('finish recording') ||
        cleaned.contains('stop video') ||
        cleaned.contains('pause recording') ||
        cleaned.contains('halt recording')) {
      return VoiceCommand.stop;
    }

    // START COMMAND VARIATIONS
    for (final w in words) {
      if (w == 'start' ||
          w == 'begin' ||
          w == 'go' ||
          w == 'record' ||
          w == 'capture' ||
          w == 'action') {
        return VoiceCommand.start;
      }
      if (w.startsWith('start') || w.startsWith('record')) {
        return VoiceCommand.start;
      }
    }

    if (cleaned.contains('start') || cleaned.contains('begin') || cleaned.contains('start recording')) {
      return VoiceCommand.start;
    }

    return null;
  }

  void _startListeningLoop() {
    if (!_isInitialized || kIsWeb) return;
    _isListening = true;

    try {
      if (_speechToText.isListening) return;

      _speechToText.listen(
        onResult: (result) {
          final recognizedWords = result.recognizedWords.trim().toLowerCase();
          _processTranscript(recognizedWords);

          // Check alternate hypotheses for instant command interception
          for (var alt in result.alternates) {
            _processTranscript(alt.recognizedWords.trim().toLowerCase());
          }
        },
        listenFor: const Duration(hours: 1),
        pauseFor: const Duration(seconds: 10),
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.deviceDefault,
      ).catchError((err) {
        debugPrint('Speech listen catchError: $err');
      });
      _onStatusChanged?.call('🎤 Listening for "Start Recording" / "Stop Recording"');
    } catch (e) {
      debugPrint('Error launching speech recognition: $e');
    }
  }

  void _restartListeningIfNeeded() {
    if (_isListening && !kIsWeb) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (_isListening && !_speechToText.isListening) {
          _startListeningLoop();
        }
      });
    }
  }

  /// Ensure speech listening is active (re-triggers listener if stopped during video recording)
  void ensureListening() {
    _isListening = true;
    if (!kIsWeb && !_speechToText.isListening) {
      _startListeningLoop();
    }
  }

  /// Manually trigger voice command for testing / web simulation
  void processSimulatedSpeech(String text) {
    if (!_isListening) return;
    _processTranscript(text.trim().toLowerCase());
  }

  /// Stop listening completely
  void stopListening() {
    _isListening = false;
    if (kIsWeb && _webSpeechRecognition != null) {
      try {
        _webSpeechRecognition.stop();
      } catch (_) {}
    } else {
      try {
        _speechToText.stop().catchError((_) {});
      } catch (_) {}
    }
    _onCommandDetected = null;
    _onStatusChanged = null;
  }
}
