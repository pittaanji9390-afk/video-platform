// Non-web stub — dart:html types not available
class MediaStream {}
class VideoElement {}
class DivElement {}
class SpeechRecognition {
  static bool get supported => false;
  SpeechRecognition();
  void start() {}
  void stop() {}
  void abort() {}
  dynamic onResult;
  dynamic onEnd;
  dynamic onError;
}
