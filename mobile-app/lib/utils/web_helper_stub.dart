const bool isWeb = false;

String? localStorageGet(String key) => null;

void localStorageSet(String key, String value) {}

void windowOpen(String url, String target) {}

class BroadcastChannelStub {
  void Function(String)? onMessageCallback;

  BroadcastChannelStub(String name);

  void close() {}
  void postMessage(String message) {}
  Stream<String> get onMessage => const Stream.empty();
}

class EventSourceStub {
  EventSourceStub(String url);
  Stream<String> get onMessage => const Stream.empty();
  void close() {}
}
