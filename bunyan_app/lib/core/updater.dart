/// تحديث التطبيق لوحده من فرع apk-flutter (من غير ما تسطّب بإيدك)
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class Updater {
  static const _ch = MethodChannel('bny/link');
  static const _base = 'https://raw.githubusercontent.com/bunyanrealstate-commits/bunyan/apk-flutter/';
  static bool _busy = false;

  static Future<String?> check({bool force = false}) async {
    if (kIsWeb || _busy) return null;
    _busy = true;
    try {
      final p = await SharedPreferences.getInstance();
      final last = p.getInt('upd_at') ?? 0;
      if (!force && DateTime.now().millisecondsSinceEpoch - last < 30 * 60000) return null;
      await p.setInt('upd_at', DateTime.now().millisecondsSinceEpoch);
      final r = await http.get(Uri.parse('${_base}version.json?t=${DateTime.now().millisecondsSinceEpoch}'));
      if (r.statusCode != 200) return null;
      final code = (jsonDecode(r.body) as Map)['code'] as int;
      final mine = await _ch.invokeMethod<int>('version') ?? 0;
      if (code <= mine) return force ? '✅ عندك آخر نسخة' : null;
      final a = await http.get(Uri.parse('${_base}Bunyan.apk?t=${DateTime.now().millisecondsSinceEpoch}'));
      if (a.statusCode != 200 || a.bodyBytes.length < 1000000) return null;
      final f = File('${(await getTemporaryDirectory()).path}/upd.apk');
      await f.writeAsBytes(a.bodyBytes, flush: true);
      await _ch.invokeMethod('install', {'path': f.path});
      return '⬆️ بنزّل نسخة جديدة من بنيان…';
    } catch (_) { return null; } finally { _busy = false; }
  }
}
