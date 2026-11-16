/// البيانات: بتتحفظ على الجهاز وبتتزامن مع نفس ملف بنيان القديم على GitHub (من غير ما حاجة تضيع)
import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'js.dart';
import 'hist.dart';
import 'merge3.dart';

class Store extends ChangeNotifier {
  static final Store I = Store._();
  Store._();

  Map<String, dynamic> S = {};
  /// إعداد المزامنة: repo / token / path / sha / dirty / last / g (Gemini) / u (المستخدم)
  Map<String, dynamic> cfg = {};
  String syncMsg = '';
  bool syncing = false;
  bool loaded = false;
  late SharedPreferences _p;

  bool get linked => truthy(cfg['token']) && truthy(cfg['repo']);

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    try { cfg = jsonDecode(_p.getString('bny_sync') ?? '{}'); } catch (_) { cfg = {}; }
    String? raw;
    try {
      if (kIsWeb) { raw = _p.getString('bny_state'); }
      else { final f = await _file(); if (await f.exists()) raw = await f.readAsString(); }
    } catch (_) {}
    if (raw != null && raw.isNotEmpty) { try { S = jsonDecode(raw); } catch (_) {} }
    resetPrev();
    loaded = true; notifyListeners();
  }

  Future<File> _file() async => File('${(await getApplicationDocumentsDirectory()).path}/book.json');

  Map<String, dynamic> strip(Map<String, dynamic> s) { final o = Map<String, dynamic>.of(s); o.remove('tab'); return o; }

  Future<void> _persist() async {
    final t = jsonOut(strip(S));
    if (kIsWeb) { await _p.setString('bny_state', t); }
    else {
      final f = await _file(); final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(t, flush: true); await tmp.rename(f.path);
    }
  }
  Future<void> saveCfg() => _saveCfg();
  void notify() => notifyListeners();
  Future<void> _saveCfg() async => _p.setString('bny_sync', jsonOut(cfg));

  /// أي تعديل: نحفظ ونعلّم إن فيه حاجة لازم تترفع
  /* ───── السجل والتراجع (نفس locLog/diff/applyUndo في القديم — القديم يقدر يتراجع عن تعديلات الجديد والعكس) ───── */
  String? _prev;
  String _snap() { final o = Map<String, dynamic>.from(S)..remove('hist')..remove('aiMem')..remove('tab'); return jsonOut(o); }
  void resetPrev() => _prev = _snap();
  /// «بعدين» في التجديد — نفس rnLater (3 أيام)
  bool snz(String key) => n0(obj(cfg['snz'])?[key]) > DateTime.now().millisecondsSinceEpoch;
  Future<void> snooze(String key) async { final m = Map<String, dynamic>.from(obj(cfg['snz']) ?? {}); m[key] = DateTime.now().millisecondsSinceEpoch + 3 * 86400000; cfg['snz'] = m; await _saveCfg(); notifyListeners(); }
  bool canUndo(Map e) => e['rev'] != true && str(e['ch']) != '[]';
  Future<void> undo(Map e) async {
    if (!canUndo(e)) return;
    Hist.applyUndo(jsonDecode(str(e['ch'])) as List, S); e['rev'] = true;
    logEv('↩ إلغاء: ${str(e['d'])}'); resetPrev();
    cfg['dirty'] = true; await _saveCfg(); await _persist(); notifyListeners();
  }

  Future<void> save({String? log}) async {
    final cur = _snap();
    if (_prev != null && cur != _prev) {
      final ch = Hist.diff(jsonDecode(_prev!) as Map, jsonDecode(cur) as Map);
      if (ch.isNotEmpty) {
        final cj = jsonOut(ch); final big = ch.length > 40 || cj.length > 150000;
        final h = lst(S['hist']).toList();
        h.insert(0, {'id': uid(), 't': DateTime.now().millisecondsSinceEpoch, 'by': str(cfg['u']).isEmpty ? 'osama' : cfg['u'], 'd': log ?? 'تعديل', 'ch': big ? '[]' : cj, 'rev': big, 'ev': big});
        S['hist'] = h.take(400).toList(); log = null;
      }
    }
    _prev = cur;
    if (log != null) logEv(log);
    cfg['dirty'] = true; await _saveCfg();
    await _persist(); notifyListeners();
  }

  /// سجل النشاط — نفس شكل بنيان القديم
  void logEv(String w) {
    final h = lst(S['hist']).toList();
    h.insert(0, {'id': uid(), 't': DateTime.now().millisecondsSinceEpoch, 'by': str(cfg['u']).isEmpty ? 'osama' : cfg['u'], 'd': w, 'ch': '[]', 'rev': true, 'ev': true});
    S['hist'] = h.take(400).toList();
  }

  static String uid() { final r = DateTime.now().microsecondsSinceEpoch.toRadixString(36); return r.substring(r.length - 7); }

  /* ───── الربط بكود من بنيان القديم ───── */
  bool link(String code) {
    final m = RegExp(r'BNYLINK-([A-Za-z0-9_-]+)').firstMatch(code.replaceAll(RegExp(r'\s+'), ''));
    if (m == null) return false;
    var s = m[1]!.replaceAll('-', '+').replaceAll('_', '/'); while (s.length % 4 != 0) { s += '='; }
    try {
      final o = jsonDecode(utf8.decode(base64.decode(s))) as Map;
      if (!truthy(o['t']) || !truthy(o['r'])) return false;
      final same = cfg['repo'] == o['r'] && (cfg['path'] ?? 'book.json') == (o['p'] ?? 'book.json');
      cfg = {'repo': o['r'], 'token': o['t'], 'path': truthy(o['p']) ? o['p'] : 'book.json', 'g': o['g'] ?? '', 'u': o['u'] ?? '',
        'sha': same ? (cfg['sha'] ?? '') : '', 'dirty': same ? (cfg['dirty'] ?? false) : false, 'last': ''};
      _saveCfg(); notifyListeners(); return true;
    } catch (_) { return false; }
  }

  Map<String, String> _h({String? acc}) => {'Authorization': 'Bearer ${cfg['token']}', 'Accept': acc ?? 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28'};
  Uri _u({bool get = false}) => Uri.parse('https://api.github.com/repos/${cfg['repo']}/contents/${Uri.encodeFull(str(cfg['path']).isEmpty ? 'book.json' : str(cfg['path']))}${get ? '?t=${DateTime.now().millisecondsSinceEpoch}' : ''}');

  Map<String, dynamic>? get _base { try { final b = _p.getString('bny_basesig_${cfg['u'] ?? ''}'); return b == null ? null : jsonDecode(b); } catch (_) { return null; } }
  Future<void> _saveBase(Map<String, dynamic> st) async => _p.setString('bny_basesig_${cfg['u'] ?? ''}', jsonOut(sig(st)));

  Future<void> _adopt(Map<String, dynamic> rem, String sha) async {
    // نسخة احتياطية قبل ما نستبدل
    try { await _p.setString('bny_pre_sync', jsonOut({'t': DateTime.now().millisecondsSinceEpoch, 's': strip(S)})); } catch (_) {}
    await _saveBase(rem); S = rem; resetPrev(); await _persist();
    cfg['sha'] = sha; cfg['dirty'] = false; await _saveCfg();
  }

  static int _lastT(Map<String, dynamic> o) { var t = 0; for (final e in objs(o['hist'])) { final d = str(e['d']); if (RegExp('تسجيل (دخول|خروج)').hasMatch(d)) continue; final x = n0(e['t']).toInt(); if (x > t) t = x; } return t; }

  /// مزامنة: نجيب من السحابة، ندمج لو الاتنين اتعدلوا، ونرفع
  Future<String> sync() async {
    if (!linked) return 'مش مربوط';
    if (syncing) return '…';
    syncing = true; notifyListeners();
    try {
      final r = await http.get(_u(get: true), headers: _h());
      if (r.statusCode == 404) { cfg['sha'] = ''; return await _push(); }
      if (r.statusCode == 401 || r.statusCode == 403) return syncMsg = '✗ المفتاح مش شغال (${r.statusCode})';
      if (r.statusCode != 200) return syncMsg = '✗ ${r.statusCode}';
      final j = jsonDecode(r.body) as Map;
      final sha = str(j['sha']);
      if (sha == cfg['sha']) { if (cfg['dirty'] == true) return await _push(); return syncMsg = '✓ ${_now()}'; }
      Map<String, dynamic> rem;
      if ((j['content'] == null || str(j['content']).isEmpty) && n0(j['size']) > 0) {
        final rr = await http.get(_u(get: true), headers: _h(acc: 'application/vnd.github.raw'));
        if (rr.statusCode != 200) return syncMsg = '✗ ${rr.statusCode}';
        rem = jsonDecode(utf8.decode(rr.bodyBytes));
      } else { rem = jsonDecode(utf8.decode(base64.decode(str(j['content']).replaceAll(RegExp(r'\s'), '')))); }
      final hasLocal = lst(S['units']).isNotEmpty || lst(S['exp']).isNotEmpty;
      if (cfg['dirty'] != true && (truthy(cfg['sha']) || !hasLocal)) { await _adopt(rem, sha); return syncMsg = '✓ نزلت آخر بيانات ${_now()}'; }
      // الاتنين اتعدلوا؟
      final mine = strip(S);
      if (jsonOut(mine) == jsonOut(rem)) { cfg['sha'] = sha; cfg['dirty'] = false; await _saveCfg(); await _saveBase(rem); return syncMsg = '✓ ${_now()}'; }
      final mg = merge3(mine, rem, _lastT(mine) > _lastT(rem), _base);
      if (mg != null && mg.l > 0 && mg.r > 0) {
        try { await _p.setString('bny_pre_sync', jsonOut({'t': DateTime.now().millisecondsSinceEpoch, 's': mine})); } catch (_) {}
        await _saveBase(rem); S = mg.s; resetPrev(); await _persist(); cfg['sha'] = sha; cfg['dirty'] = true;
        await _push(); return syncMsg = '🔀 دمجت تعديلاتك مع السحابة';
      }
      if (mg != null && mg.l == 0 && mg.r > 0) { await _adopt(rem, sha); return syncMsg = '✓ نزلت آخر بيانات'; }
      if (mg != null && mg.l > 0 && mg.r == 0) { cfg['sha'] = sha; return await _push(); }
      // من غير أساس: الأحدث يكسب (زي القديم)
      if (_lastT(rem) >= _lastT(mine)) { await _adopt(rem, sha); return syncMsg = 'خدت نسخة السحابة لأنها الأحدث'; }
      cfg['sha'] = sha; return await _push();
    } catch (e) { return syncMsg = '✗ مفيش نت؟'; }
    finally { syncing = false; await _saveCfg(); notifyListeners(); }
  }

  Future<String> _push() async {
    final src = strip(S);
    final body = {'message': 'sync ${DateTime.now().toUtc().toIso8601String()}', 'content': base64.encode(utf8.encode(jsonOut(src)))};
    if (truthy(cfg['sha'])) body['sha'] = cfg['sha'];
    final r = await http.put(_u(), headers: {..._h(), 'Content-Type': 'application/json'}, body: jsonEncode(body));
    if (r.statusCode == 200 || r.statusCode == 201) {
      cfg['sha'] = (jsonDecode(r.body) as Map)['content']['sha']; cfg['dirty'] = false; await _saveBase(src);
      return syncMsg = '✓ اترفعت ${_now()}';
    }
    if (r.statusCode == 409 || r.statusCode == 422) { cfg['dirty'] = true; syncing = false; return await sync(); }
    return syncMsg = '✗ ${r.statusCode}';
  }

  String _now() { final d = DateTime.now(); return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'; }
}
