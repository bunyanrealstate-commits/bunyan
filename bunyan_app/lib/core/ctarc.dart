/// 📁 العقود المحفوظة: كل عقد بيتحفظ لوحده في S['ctArc'] (بياناته كلها)، وصور الهويات
/// بتتحفظ على الموبايل + نسخة في الريبو (files/ct/...) عشان ماتضيعش لو الموبايل اتغير
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'js.dart';
import 'store.dart';

class CtArc {
  static List<dynamic> all(Obj S) { final a = S['ctArc']; if (a is List) return a; final l = <dynamic>[]; S['ctArc'] = l; return l; }
  static String uid() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  /// رقم العقد الحالي في الأرشيف (بيتعمل أول مرة)
  static String aid(Map<String, dynamic> c) { if (!truthy(c['aid'])) c['aid'] = uid(); return str(c['aid']); }

  static bool worth(Map c) { final f = obj(c['f']) ?? {}; return str(f['tn']).trim().isNotEmpty || str(f['tid']).trim().isNotEmpty || truthy(obj(c['img'])?['tn']); }

  /// بيحدّث نسخة العقد الحالي في الأرشيف (أو يضيفها) — بيتنده مع كل حفظ
  static void upsert(Obj S, Map<String, dynamic> c) {
    if (!worth(c)) return;
    final id = aid(c); final f = obj(c['f']) ?? {};
    final copy = jsonDecode(jsonEncode(c)) as Map<String, dynamic>..remove('html')..remove('ids');
    final e = <String, dynamic>{'id': id, 'at': DateTime.now().millisecondsSinceEpoch, 'tn': str(f['tn']), 'tid': str(f['tid']), 'ph': str(f['ph']), 'sub': str(f['sub']), 'subU': str(c['subU']), 'st': str(f['st']), 'en': str(f['en']), 'ct': copy};
    final L = all(S); final i = L.indexWhere((x) => x is Map && x['id'] == id);
    if (i >= 0) { final o = L[i] as Map; e['c0'] = o['c0'] ?? o['at']; L[i] = e; } else { e['c0'] = e['at']; L.insert(0, e); }
  }

  /// يفتح عقد محفوظ في الشاشة (العقد الحالي محفوظ أصلاً في الأرشيف)
  static void open(Obj S, Map e) {
    final cur = obj(S['ct']) ?? {};
    final c = jsonDecode(jsonEncode(e['ct'])) as Map<String, dynamic>;
    c['aid'] = e['id']; c['html'] = '';
    // التوقيعات المحفوظة والمؤجر بتفضل زي ما هي لو العقد القديم ماكانش فيه
    for (final k in ['sig']) { if (!truthy(c[k]) && truthy(cur[k])) c[k] = cur[k]; }
    S['ct'] = c;
  }

  static void del(Obj S, String id) => all(S).removeWhere((x) => x is Map && x['id'] == id);

  /* ───── صور الهويات ───── */
  static Future<String> _dir() async { final d = await getApplicationDocumentsDirectory(); final x = Directory('${d.path}/ctimg'); if (!x.existsSync()) x.createSync(recursive: true); return x.path; }

  /// بيحفظ الصورة ويرجّع اسمها (ct/<aid>_tn.jpg)
  static Future<String> putImg(String name, Uint8List b) async {
    final key = 'ct/$name.jpg';
    try {
      if (kIsWeb) { final p = await SharedPreferences.getInstance(); await p.setString('bny_img_$key', base64.encode(b)); }
      else { await File('${await _dir()}/$name.jpg').writeAsBytes(b, flush: true); }
    } catch (_) {}
    _upload(key, b); // في الخلفية
    return key;
  }

  static final Map<String, Uint8List> _mem = {};
  static Future<Uint8List?> img(String key) async {
    if (key.isEmpty) return null;
    if (_mem[key] != null) return _mem[key];
    final name = key.replaceFirst('ct/', '').replaceAll('.jpg', '');
    try {
      if (kIsWeb) { final p = await SharedPreferences.getInstance(); final s = p.getString('bny_img_$key'); if (s != null) return _mem[key] = base64.decode(s); }
      else { final f = File('${await _dir()}/$name.jpg'); if (f.existsSync()) return _mem[key] = await f.readAsBytes(); }
    } catch (_) {}
    // مش على الموبايل؟ نجيبها من الريبو
    final st = Store.I; if (!st.linked) return null;
    try {
      final r = await http.get(Uri.parse('https://api.github.com/repos/${st.cfg['repo']}/contents/files/$key'), headers: {'Authorization': 'Bearer ${st.cfg['token']}', 'Accept': 'application/vnd.github.raw'}).timeout(const Duration(seconds: 25));
      if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) {
        final b = r.bodyBytes;
        try { if (!kIsWeb) await File('${await _dir()}/$name.jpg').writeAsBytes(b, flush: true); } catch (_) {}
        return _mem[key] = b;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> _upload(String key, Uint8List b) async {
    _mem[key] = b;
    final st = Store.I; if (!st.linked) return;
    final u = Uri.parse('https://api.github.com/repos/${st.cfg['repo']}/contents/files/$key');
    final h = {'Authorization': 'Bearer ${st.cfg['token']}', 'Accept': 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28'};
    try {
      String? sha; final g = await http.get(u, headers: h).timeout(const Duration(seconds: 20));
      if (g.statusCode == 200) sha = str(jsonDecode(g.body)['sha']);
      await http.put(u, headers: h, body: jsonEncode({'message': '🪪 contract ID image', 'content': base64.encode(b), if (sha != null && sha.isNotEmpty) 'sha': sha})).timeout(const Duration(seconds: 40));
    } catch (_) {}
  }
}
