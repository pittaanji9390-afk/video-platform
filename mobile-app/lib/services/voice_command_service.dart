import 'package:flutter/foundation.dart';
import 'dart:async';
import 'vosk_voice_command_service.dart';
import '../utils/html_helper.dart' as html;

enum VoiceCommand { start, stop }

class VoiceCommandService {
  VoiceCommandService._();
  static final VoiceCommandService instance = VoiceCommandService._();

  final VoskVoiceCommandService _voskService = VoskVoiceCommandService();
  bool _isListening = false;
  bool get isListening => _isListening;

  VoiceCommand? _lastCommand;
  DateTime? _lastCommandTime;
  static const Duration _commandCooldown = Duration(seconds: 2);

  void Function(VoiceCommand command)? _onCommandDetected;
  void Function(String statusMessage)? _onStatusChanged;

  /// Initialize and start continuous Vosk offline speech recognition
  Future<void> startListening({
    required void Function(VoiceCommand command) onCommand,
    void Function(String statusMessage)? onStatusChanged,
  }) async {
    _onCommandDetected = onCommand;
    _onStatusChanged = onStatusChanged;
    _isListening = true;

    _onStatusChanged?.call('🎤 Listening for "Start Recording" / "Stop Recording" via Vosk');

    await _voskService.startListening(
      onCommand: (command, rawPhrase) {
        if (command == 'start_recording') {
          _processTranscript('start');
        } else if (command == 'stop_recording') {
          _processTranscript('stop');
        }
      },
    );
  }
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

  /// Match voice input against "Start Recording" & "Stop Recording", ignoring all other speech
  VoiceCommand? _matchCommand(String text) {
    // Strip punctuation marks to prevent "stop.", "stop!", "stop recording!" matching failures
    final cleaned = text.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    if (cleaned.isEmpty) return null;

    // Check for Stop variations: "stop", "stop recording", "stop record", "stop video", "please stop", "end recording", "finish recording", "cut", "halt", "done", "pause"
    if (cleaned.contains('stop') || 
        cleaned.contains('stopp') || 
        cleaned.contains('top recording') || 
        cleaned.contains('end recording') || 
        cleaned.contains('finish') || 
        cleaned.contains('pause') || 
        cleaned == 'cut' || 
        cleaned == 'halt' || 
        cleaned == 'done') {
      return VoiceCommand.stop;
    }

    // Check for Start variations: "start", "start recording", "start record", "begin recording", "action"
    if (cleaned.contains('start') || 
        cleaned.contains('begin') || 
        cleaned.contains('action')) {
      return VoiceCommand.start;
    }

    // Ignore all other speech
    return null;
  }

  void _startListeningLoop() {
    if (!_isInitialized || kIsWeb) return;
    _isListening = true;

    try {
      if (_speechToText.isListening) return;

      _speechToText.listen(
        onResult: (result) {
          final recognizedWords = result.recognizedWords;
          if (recognizedWords.isNotEmpty) {
            _processTranscript(recognizedWords);
          }

          // Check alternate hypotheses for instant command interception
          for (var alt in result.alternates) {
            if (alt.recognizedWords.isNotEmpty) {
              _processTranscript(alt.recognizedWords);
            }
          }
        },
        listenFor: const Duration(hours: 1),
        pauseFor: const Duration(seconds: 60),
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
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
      Future.delayed(const Duration(milliseconds: 600), () {
        if (_isListening && !_speechToText.isListening) {
          _startListeningLoop();
        }
      });
    }
  }

  /// Ensure speech listening is active
  void ensureListening() {
    _isListening = true;
    startListening(
      onCommand: _onCommandDetected ?? (_) {},
      onStatusChanged: _onStatusChanged,
    );
  }

  /// Manually trigger voice command for testing / web simulation
  void processSimulatedSpeech(String text) {
    if (!_isListening) return;
    _processTranscript(text.trim().toLowerCase());
  }

  /// Stop listening completely
  void stopListening() {
    _isListening = false;
    _voskService.stopListening();
    _onCommandDetected = null;
    _onStatusChanged = null;
  }
}
