import 'dart:async';
import 'dart:html' as html;

const bool isWeb = true;

class BroadcastChannelStub {
  late html.BroadcastChannel _bc;
  
  BroadcastChannelStub(String name) {
    _bc = html.BroadcastChannel(name);
  }
  
  void close() => _bc.close();
  
  void postMessage(String message) {
    _bc.postMessage(message);
  }
  
  Stream<String> get onMessage {
    final controller = StreamController<String>();
    _bc.onMessage.listen((event) {
      controller.add(event.data?.toString() ?? '');
    });
    return controller.stream;
  }
}

void windowOpen(String url, String target) {
  html.window.open(url, target);
}

String? localStorageGet(String key) {
  return html.window.localStorage[key];
}

void localStorageSet(String key, String value) {
  html.window.localStorage[key] = value;
}

class EventSourceStub {
  late html.EventSource? _es;
  final StreamController<String> _controller = StreamController<String>.broadcast();
  
  EventSourceStub(String url) {
    try {
      _es = html.EventSource(url);
      _es!.onMessage.listen((event) {
        _controller.add(event.data?.toString() ?? '');
      });
    } catch (_) {
      _es = null;
    }
  }
  
  Stream<String> get onMessage => _controller.stream;
  
  void close() {
    _es?.close();
    _controller.close();
  }
}
