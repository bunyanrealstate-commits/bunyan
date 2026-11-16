/// 📢 الأبديت — نفس ملف upd.json / upd_f.json اللي بنيان القديم بيعمله باك أب في الريبو (الأحدث at يكسب)
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'js.dart';
import 'store.dart';

class Upd {
  static const FL = [['G', 'أرضي', 'G FLOOR'], ['1', 'أول', '1ST FLOOR'], ['2', 'تاني', '2ND FLOOR'], ['3', 'تالت', '3RD FLOOR'], ['R', 'روف', 'ROOF']];
  static const TY = [['st', 'استديو', 'STUDIO'], ['1bk', 'غرفة وصالة', '1 BHK'], ['2bk', 'غرفتين وصالة', '2 BHK'], ['1bk2b', 'غرفة وصالة وحمامين', '1 BHK + 2 BATH'], ['2bk2b', 'غرفتين وصالة وحمامين', '2 BHK + 2 BATH'], ['x', 'نوع تاني (اكتبه)', '']];
  static String lab(List<List<String>> L, dynamic k, int i) => L.where((x) => x[0] == '$k').map((x) => x[i]).firstOrNull ?? '';
  static String file(String mode) => mode == 'f' ? 'upd_f.json' : 'upd.json';
  static Map<String, dynamic> blank() => {'title': 'AL SHAMKHA SOUTH', 'phone': '0528091984', 'fee': 500, 'dep': '1 Month (Cheque)', 'group': '', 'notes': '', 'hideBooked': false, 'at': 0, 'villas': <dynamic>[]};

  static Map<String, String> _h() => {'Authorization': 'Bearer ${Store.I.cfg['token']}', 'Accept': 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28'};
  static Uri _u(String mode, {bool t = false}) => Uri.parse('https://api.github.com/repos/${Store.I.cfg['repo']}/contents/${file(mode)}${t ? '?t=${DateTime.now().millisecondsSinceEpoch}' : ''}');

  static Future<Map<String, dynamic>> local(String mode) async { final p = await SharedPreferences.getInstance(); final s = p.getString('bny_upd_$mode'); if (s != null) { try { return jsonDecode(s) as Map<String, dynamic>; } catch (_) {} } return blank(); }
  static Future<void> _keep(String mode, Map d) async { final p = await SharedPreferences.getInstance(); await p.setString('bny_upd_$mode', jsonOut(d)); }

  /// بيجيب من الريبو لو أحدث
  static Future<Map<String, dynamic>> pull(String mode) async {
    var d = await local(mode);
    if (!Store.I.linked) return d;
    try {
      final r = await http.get(_u(mode, t: true), headers: _h()).timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body); final x = jsonDecode(utf8.decode(base64.decode(str(j['content']).replaceAll('\n', '')))) as Map<String, dynamic>;
        if (n0(x['at']) > n0(d['at'])) { d = x; await _keep(mode, d); }
      }
    } catch (_) {}
    return d;
  }

  static Future<bool> save(String mode, Map<String, dynamic> d) async {
    final prev = n0(d['at']); d['at'] = DateTime.now().millisecondsSinceEpoch; await _keep(mode, d);
    if (!Store.I.linked) return false;
    try {
      String? sha; final g = await http.get(_u(mode, t: true), headers: _h()).timeout(const Duration(seconds: 20));
      if (g.statusCode == 200) {
        final j = jsonDecode(g.body); sha = str(j['sha']);
        // حماية: لو النسخة اللي في الريبو اتعدلت بعد ما فتحنا (من القديم) منكتبش فوقها
        final x = jsonDecode(utf8.decode(base64.decode(str(j['content']).replaceAll('\n', '')))) as Map;
        if (n0(x['at']) > prev) return false;
      } else if (g.statusCode != 404) { return false; }
      final r = await http.put(_u(mode), headers: _h(), body: jsonEncode({'message': '📢 update list (Flutter)', 'content': base64.encode(utf8.encode(jsonOut(d))), if (sha != null && sha.isNotEmpty) 'sha': sha})).timeout(const Duration(seconds: 25));
      return r.statusCode == 200 || r.statusCode == 201;
    } catch (_) { return false; }
  }

  static String typeEn(Map a) => '${truthy(a['furn']) ? 'FURNISHED ' : ''}${a['type'] == 'x' ? str(a['tx']).toUpperCase() : lab(TY, a['type'], 2)}';
  static String typeAr(Map a) => a['type'] == 'x' ? str(a['tx']) : lab(TY, a['type'], 1);
  static String nf(dynamic v) { final x = double.tryParse(str(v).replaceAll(RegExp(r'[^\d.]'), '')) ?? 0; if (x == 0) return ''; return x.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ','); }
  static Map<String, dynamic> PM(Map d) => {'m': truthy(d['pm']) ? str(d['pm']) : 'range', 'n': n0(d['pn']) != 0 ? n0(d['pn']).toInt() : 3, 'mo': d['showMo'] != false};
  /// أعمدة الأسعار (cols)
  static List<Map<String, dynamic>> cols(Map d) {
    final c = PM(d); final o = <Map<String, dynamic>>[]; final nn = c['n'] as int;
    if (c['m'] == 'sep') { for (var i = 1; i <= nn; i++) { final k = i; o.add({'h': i == 1 ? '1 PAYMENT' : '$i PAYMENTS', 'v': (Map a) => truthy(a['p$k']) ? a['p$k'] : (k == 1 ? a['price'] : 0)}); } }
    else { o.add({'h': c['m'] == 'single' ? (nn == 1 ? '1 PAYMENT' : '$nn PAYMENTS') : '1 – $nn PAYMENTS', 'v': (Map a) => truthy(a['price']) ? a['price'] : a['p1']}); }
    if (c['mo'] == true) o.add({'h': 'MONTHLY', 'v': (Map a) => a['mo'], 'mo': 1});
    return o;
  }
  static bool shown(Map d, Map a) => !truthy(a['hide']) && !(truthy(d['hideBooked']) && truthy(a['booked']));
  static List<Map<String, String>> phl(Map d) { final N = lst(d['phnm']); return [d['phone'], ...lst(d['phones'])].indexed.map((e) => {'p': str(e.$2).replaceAll('​', '').trim(), 'n': e.$1 < N.length ? str(N[e.$1]).trim() : ''}).where((x) => x['p']!.isNotEmpty).toList(); }

  /// نص الواتساب (txt) — نفس القديم
  static String txt(Map d) {
    final now = DateTime.now(); final o = <String>['🏠 *${str(d['title'])}* — AVAILABLE NOW', '🗓 ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}', ''];
    for (final v in objs(d['villas'])) {
      final L = objs(v['units']).where((a) => shown(d, a)).toList(); if (L.isEmpty) continue;
      o.add('🏡 *${str(v['name'])}*${truthy(v['area']) ? ' — ${v['area']}' : ''}'); if (truthy(v['note'])) o.add('📝 ${v['note']}'); if (truthy(v['loc'])) o.add('📍 ${v['loc']}');
      for (final a in L) {
        final parts = [lab(FL, a['floor'], 2), if (truthy(a['no'])) 'Flat ${a['no']}', typeEn(a)].where((x) => x.isNotEmpty).join(' | ');
        final pr = truthy(a['booked']) ? '❌ BOOKED' : cols(d).where((x) => truthy((x['v'] as Function)(a))).map((x) => '${x['mo'] == 1 ? 'Monthly' : x['h']} ${nf((x['v'] as Function)(a))}').join(' / ');
        o.add('• $parts — $pr'); if (truthy(a['note'])) o.add('   📝 ${a['note']}');
      }
      o.add('');
    }
    o.add('📝 Contract fee: ${nf(d['fee'])} AED'); o.add('🔐 Security deposit: ${str(d['dep'])}'); if (truthy(d['notes'])) o.add(str(d['notes']));
    o.add('📞 ${phl(d).map((x) => '${x['n']!.isNotEmpty ? '${x['n']}: ' : ''}${x['p']}').join(' / ')}');
    return o.join('\n');
  }
  static String uid() { final r = DateTime.now().microsecondsSinceEpoch.toRadixString(36); return r.substring(r.length - 7); }
}
