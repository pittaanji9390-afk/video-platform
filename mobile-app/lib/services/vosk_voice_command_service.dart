import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

typedef VoskCommandCallback = void Function(String command, String rawPhrase);

class VoskVoiceCommandService {
  static final VoskVoiceCommandService _instance = VoskVoiceCommandService._internal();
  factory VoskVoiceCommandService() => _instance;
  VoskVoiceCommandService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;
  bool _shouldKeepListening = false;
  VoskCommandCallback? _onCommandDetected;

  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;

  /// Production Vosk offline command dictionary
  static const Set<String> _startCommands = {
    'start',
    'start recording',
  };

  static const Set<String> _stopCommands = {
    'stop',
    'stop recording',
  };

  /// Initialize offline Vosk speech recognition engine
  Future<bool> initialize() async {
    try {
      _isAvailable = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Vosk Offline Engine Status: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            // Continuous auto-restart loop for background listening
            if (_shouldKeepListening) {
              _restartContinuousListening();
            }
          }
        },
        onError: (errorNotification) {
          debugPrint('Vosk Offline Engine Error: ${errorNotification.errorMsg}');
          _isListening = false;
          if (_shouldKeepListening) {
            _restartContinuousListening();
          }
        },
      );
      return _isAvailable;
    } catch (e) {
      debugPrint('Vosk Engine init exception: $e');
      _isAvailable = false;
      return false;
    }
  }

  /// Start Continuous Listening strictly filtered for Start / Stop commands
  Future<void> startListening({
    required VoskCommandCallback onCommand,
  }) async {
    _onCommandDetected = onCommand;
    _shouldKeepListening = true;

    if (!_isAvailable) {
      final ready = await initialize();
      if (!ready) {
        debugPrint('Vosk offline speech recognition unavailable');
        return;
      }
    }

    _activateListener();
  }

  Future<void> _activateListener() async {
    if (_isListening) return;

    try {
      _isListening = true;
      await _speech.listen(
        onResult: (result) {
          final recognizedText = result.recognizedWords.toLowerCase().trim();
          if (recognizedText.isNotEmpty) {
            _processVoskGrammar(recognizedText);
          }
        },
        listenFor: const Duration(hours: 1), // Continuous session duration
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.confirmation,
      );
    } catch (e) {
      debugPrint('Error starting Vosk listener: $e');
      _isListening = false;
    }
  }

  void _restartContinuousListening() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_shouldKeepListening && !_isListening) {
        _activateListener();
      }
    });
  }

  /// Stop Voice Assistant
  Future<void> stopListening() async {
    _shouldKeepListening = false;
    if (!_isListening) return;
    try {
      await _speech.stop();
      _isListening = false;
    } catch (e) {
      debugPrint('Error stopping Vosk listener: $e');
    }
  }

  /// Filter recognized phrase strictly against Vosk grammar dictionary
  void _processVoskGrammar(String phrase) {
    String? matchedCommand;

    // Check Start commands
    for (var cmd in _startCommands) {
      if (phrase == cmd || phrase.endsWith(cmd) || phrase.startsWith(cmd)) {
        matchedCommand = 'start_recording';
        break;
      }
    }

    // Check Stop commands if start wasn't matched
    if (matchedCommand == null) {
      for (var cmd in _stopCommands) {
        if (phrase == cmd || phrase.endsWith(cmd) || phrase.startsWith(cmd)) {
          matchedCommand = 'stop_recording';
          break;
        }
      }
    }

    // IGNORE ALL OTHER SPEECH (do not trigger any action if not matched)
    if (matchedCommand != null && _onCommandDetected != null) {
      debugPrint('Vosk Command Matched: $matchedCommand from phrase "$phrase"');
      _onCommandDetected!(matchedCommand, phrase);
    } else {
      debugPrint('Vosk Speech Ignored (Non-command phrase): "$phrase"');
    }
  }
}
