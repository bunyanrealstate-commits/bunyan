/// أندرويد: الإرسال للواتساب (الفيديو + الرسالة لرقم العميل)، كود الربط من بنيان، والتحديث التلقائي
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'store.dart';

class Native {
  static const ch = MethodChannel('offers/native');
  static const _base = 'https://raw.githubusercontent.com/bunyanrealstate-commits/bunyan/apk-offers/';
  static final upd = ValueNotifier<String?>(null);
  static int mine = 0, latest = 0;

  static String phone(String s) { var p = s.replaceAll(RegExp(r'[^\d]'), ''); if (p.startsWith('00')) p = p.substring(2); if (RegExp(r'^05\d{8}$').hasMatch(p)) p = '971${p.substring(1)}'; if (RegExp(r'^5\d{8}$').hasMatch(p)) p = '971$p'; return p; }

  /// بيفتح شات العميل في الواتساب ومعاه الفيديوهات والرسالة — تدوس إرسال
  static Future<String> sendWa({required String phone, required String text, required List<String> uris}) async {
    if (!kIsWeb) {
      try { final r = await ch.invokeMethod<String>('wa', {'phone': Native.phone(phone), 'text': text, 'uris': uris}); if (r != null) return r; } catch (_) {}
    }
    await Share.share(text); return 'share';
  }

  /// أسماء العملاء من جهات الاتصال (اللي على الواتساب الأول)
  static List<Map<String, String>>? _contacts;
  static Future<List<Map<String, String>>> contacts() async {
    if (_contacts != null && _contacts!.isNotEmpty) return _contacts!;
    if (kIsWeb) return [];
    try {
      final r = await ch.invokeMethod<List>('contacts') ?? [];
      final seen = <String>{};
      final out = <Map<String, String>>[];
      for (final m in r.whereType<Map>()) {
        final p = phone('${m['p'] ?? ''}');
        if (p.length < 8 || !seen.add(p)) continue;
        out.add({'n': '${m['n'] ?? ''}', 'p': p, 'wa': '${m['wa'] ?? ''}'});
      }
      out.sort((a, b) => a['n']!.compareTo(b['n']!));
      return _contacts = out;
    } catch (_) { return []; }
  }

  static Future<bool> takeLink() async {
    if (kIsWeb) return false;
    try { final l = await ch.invokeMethod<String>('take'); if (l == null || !l.contains('c=')) return false; return Store.I.link(Uri.parse(l).queryParameters['c'] ?? ''); } catch (_) { return false; }
  }

  static DateTime _last = DateTime(2000);
  /// التحديث: أندرويد بينزّل النسخة الجديدة (مقاس صغير) ويسطّبها — وكمان بيشيك لوحده في الخلفية
  static Future<void> check({bool force = false}) async {
    if (kIsWeb) return;
    if (!force && DateTime.now().difference(_last).inSeconds < 90) return;
    _last = DateTime.now();
    try {
      mine = await ch.invokeMethod<int>('version') ?? 0;
      final r = await http.get(Uri.parse('${_base}version.json?t=${DateTime.now().millisecondsSinceEpoch}')).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return;
      latest = (jsonDecode(r.body) as Map)['code'] as int;
      if (latest <= mine) { upd.value = null; return; }
      if (!(await ch.invokeMethod<bool>('canInstall') ?? true)) { upd.value = 'perm'; return; }
      upd.value = 'dl';
      final res = await ch.invokeMethod<String>('upd');
      upd.value = res == 'inst' ? 'inst' : (res == 'same' ? null : 'new');
    } catch (_) { if (latest > mine) upd.value = 'new'; }
  }
  static Future<void> askPerm() async { try { await ch.invokeMethod('installPerm'); } catch (_) {} }
}
