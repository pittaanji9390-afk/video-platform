// Conditional export: dart:html on web, stub on other platforms
export 'html_stub.dart'
    if (dart.library.html) 'html_web.dart';
