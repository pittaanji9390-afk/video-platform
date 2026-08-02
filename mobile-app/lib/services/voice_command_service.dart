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

  // Debounce: prevent rapid re-triggering of same command
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

        _webSpeechRecognition.onResult.listen((event) {
          try {
            final results = event.results;
            if (results != null) {
              final len = results.length ?? 0;
              for (var i = 0; i < len; i++) {
                try {
                  final item = results[i];
                  if (item != null) {
                    final alt = item[0];
                    final transcript = (alt?.transcript ?? '').toString().toLowerCase().trim();
                    _processTranscript(transcript);
                  }
                } catch (_) {}
              }
            }
          } catch (_) {}
        });

        _webSpeechRecognition.onEnd.listen((_) {
          if (_isListening) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (_isListening) {
                try {
                  _webSpeechRecognition.start();
                } catch (_) {}
              }
            });
          }
        });

        _webSpeechRecognition.onError.listen((e) {
          debugPrint('Web Speech Error: $e');
          if (_isListening) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_isListening) {
                try {
                  _webSpeechRecognition.start();
                } catch (_) {}
              }
            });
          }
        });

        try {
          _webSpeechRecognition.start();
        } catch (_) {}
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

    // Debounce check
    final now = DateTime.now();
    if (_lastCommandTime != null && now.difference(_lastCommandTime!) < _commandCooldown) {
      return;
    }

    // Strict matching: only exact phrases or single words
    // Avoid false positives from words like "restart", "stopwatch", "starting"
    final VoiceCommand? command = _matchCommand(text);
    if (command != null) {
      _lastCommandTime = now;
      _onCommandDetected?.call(command);
    }
  }

  /// Match voice input against known commands using strict rules
  VoiceCommand? _matchCommand(String text) {
    final cleaned = text.trim().toLowerCase();

    // Exact single-word matches
    if (cleaned == 'start' || cleaned == 'go' || cleaned == 'begin') {
      return VoiceCommand.start;
    }
    if (cleaned == 'stop' || cleaned == 'halt' || cleaned == 'end') {
      return VoiceCommand.stop;
    }

    // Phrase matches — must be the full utterance or start of it
    if (cleaned == 'start recording' || cleaned.startsWith('start recording') ||
        cleaned == 'start video' || cleaned.startsWith('start video')) {
      return VoiceCommand.start;
    }
    if (cleaned == 'stop recording' || cleaned.startsWith('stop recording') ||
        cleaned == 'stop video' || cleaned.startsWith('stop video')) {
      return VoiceCommand.stop;
    }

    // Reject partial matches like "restart", "stopwatch", "starting", "stopping"
    return null;
  }

  void _startListeningLoop() {
    if (!_isInitialized || kIsWeb) return;
    _isListening = true;

    try {
      _speechToText.listen(
        onResult: (result) {
          final recognizedWords = result.recognizedWords.trim().toLowerCase();
          _processTranscript(recognizedWords);
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.confirmation,
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
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_isListening) {
          _startListeningLoop();
        }
      });
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
