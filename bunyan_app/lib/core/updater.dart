/// تحديث التطبيق لوحده من فرع apk-flutter (من غير ما تسطّب بإيدك)
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'build.dart';

class Updater {
  static const _ch = MethodChannel('bny/link');
  static const _base = 'https://raw.githubusercontent.com/bunyanrealstate-commits/bunyan/apk-flutter/';
  static bool _busy = false;
  /// حالة التحديث اللي بتظهر كشريط فوق: null = مفيش حاجة
  static final state = ValueNotifier<String?>(null);
  static bool needPerm = false;
  static int mine = 0, latest = 0;

  static Future<int> myVersion() async { try { mine = await _ch.invokeMethod<int>('version') ?? 0; } catch (_) {} return mine; }

  static Future<String?> check({bool force = false}) async {
    if (kIsWeb || _busy) return null;
    _busy = true;
    try {
      final p = await SharedPreferences.getInstance();
      final last = p.getInt('upd_at') ?? 0;
      if (!force && DateTime.now().millisecondsSinceEpoch - last < 3 * 60000) return null;
      await p.setInt('upd_at', DateTime.now().millisecondsSinceEpoch);
      final r = await http.get(Uri.parse('${_base}version.json?t=${DateTime.now().millisecondsSinceEpoch}')).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return null;
      latest = (jsonDecode(r.body) as Map)['code'] as int;
      await myVersion();
      if (latest <= mine) { state.value = null; return force ? '✅ عندك آخر نسخة ($mine)' : null; }
      final can = await _ch.invokeMethod<bool>('canInstall') ?? true;
      if (!can) { needPerm = true; state.value = 'perm'; return null; }
      needPerm = false;
      state.value = 'dl';
      final a = await http.get(Uri.parse('$_base${kHakim ? 'Hakim' : 'Bunyan'}.apk?t=${DateTime.now().millisecondsSinceEpoch}')).timeout(const Duration(minutes: 4));
      if (a.statusCode != 200 || a.bodyBytes.length < 1000000) { state.value = 'new'; return null; }
      final f = File('${(await getTemporaryDirectory()).path}/upd.apk');
      await f.writeAsBytes(a.bodyBytes, flush: true);
      await _ch.invokeMethod('install', {'path': f.path});
      state.value = 'inst';
      return '⬆️ بنزّل نسخة جديدة من بنيان…';
    } catch (_) { if (latest > mine) state.value = 'new'; return null; } finally { _busy = false; }
  }

  static Future<void> askPerm() async { try { await _ch.invokeMethod('installPerm'); } catch (_) {} }
}
