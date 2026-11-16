/// التواصل مع أندرويد: كود الربط اللي بنيان القديم بيبعته لوحده، وفتح بنيان القديم
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'store.dart';

class Native {
  static const _ch = MethodChannel('bny/link');
  static bool _inited = false;

  static void init() {
    if (_inited || kIsWeb) return; _inited = true;
    _ch.setMethodCallHandler((c) async { if (c.method == 'ping') await takeLink(); return null; });
  }

  /// لو بنيان القديم بعت كود ربط: نربط ونحمّل كل البيانات من غير ما تعمل حاجة
  static Future<bool> takeLink() async {
    if (kIsWeb) return false;
    try {
      final l = await _ch.invokeMethod<String>('take');
      if (l == null || !l.contains('c=')) return false;
      final code = Uri.parse(l).queryParameters['c'] ?? '';
      if (!Store.I.link(code)) return false;
      await Store.I.sync();
      Store.I.S['flutLinked'] = DateTime.now().millisecondsSinceEpoch;
      await Store.I.save();
      Store.I.sync();
      return true;
    } catch (_) { return false; }
  }

  static Future<bool> openOld() async { try { return await _ch.invokeMethod<bool>('openOld') ?? false; } catch (_) { return false; } }
}
