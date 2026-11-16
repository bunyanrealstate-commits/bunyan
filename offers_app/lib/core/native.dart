/// أندرويد: الإرسال للواتساب (الفيديو + الرسالة لرقم العميل)، كود الربط من بنيان، والتحديث التلقائي
import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
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

  static Future<bool> takeLink() async {
    if (kIsWeb) return false;
    try { final l = await ch.invokeMethod<String>('take'); if (l == null || !l.contains('c=')) return false; return Store.I.link(Uri.parse(l).queryParameters['c'] ?? ''); } catch (_) { return false; }
  }

  static Future<void> check({bool force = false}) async {
    if (kIsWeb) return;
    try {
      final r = await http.get(Uri.parse('${_base}version.json?t=${DateTime.now().millisecondsSinceEpoch}')).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return;
      latest = (jsonDecode(r.body) as Map)['code'] as int;
      mine = await ch.invokeMethod<int>('version') ?? 0;
      if (latest <= mine) { upd.value = null; return; }
      if (!(await ch.invokeMethod<bool>('canInstall') ?? true)) { upd.value = 'perm'; return; }
      upd.value = 'dl';
      final a = await http.get(Uri.parse('${_base}Offers.apk?t=${DateTime.now().millisecondsSinceEpoch}')).timeout(const Duration(minutes: 4));
      if (a.statusCode != 200 || a.bodyBytes.length < 1000000) { upd.value = 'new'; return; }
      final f = File('${(await getTemporaryDirectory()).path}/upd.apk'); await f.writeAsBytes(a.bodyBytes, flush: true);
      await ch.invokeMethod('install', {'path': f.path}); upd.value = 'inst';
    } catch (_) { if (latest > mine) upd.value = 'new'; }
  }
  static Future<void> askPerm() async { try { await ch.invokeMethod('installPerm'); } catch (_) {} }
}
