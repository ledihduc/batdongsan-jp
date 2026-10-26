// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

Future<String?> readToken(String key) async => html.window.localStorage[key];

Future<void> writeToken(String key, String value) async {
  html.window.localStorage[key] = value;
}

Future<void> deleteToken(String key) async {
  html.window.localStorage.remove(key);
}
