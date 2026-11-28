/// البيانات: بتتحفظ على الجهاز وبتتزامن مع نفس ملف بنيان القديم على GitHub (من غير ما حاجة تضيع)
import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'build.dart';
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
    if (kHakim) noAmr(S);
    resetPrev();
    loaded = true; notifyListeners();
  }

  Future<File> _file() async => File('${(await getApplicationDocumentsDirectory()).path}/book.json');

  Map<String, dynamic> strip(Map<String, dynamic> s) { final o = Map<String, dynamic>.of(s); o.remove('tab'); return o; }

  /// للاختبارات: بيانات في الذاكرة من غير ملفات
  bool testMode = false;
  Future<void> initTest(Map<String, dynamic> s) async { _p = await SharedPreferences.getInstance(); S = s; cfg = {'lang': 'ar'}; loaded = true; testMode = true; resetPrev(); }

  Future<void> _persist() async {
    if (testMode) return;
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

  /// رسالة سريعة للشاشة (main.dart بيربطها بالـ SnackBar)
  void Function(String)? onMsg;
  int _roT = 0;
  /// نسخة حكيم: الحسابات للعرض بس — دول المفاتيح الممنوع تتغير (العقود والأبديت مسموحين)
  static const _hkLocked = ['units', 'groups', 'exp', 'dep', 'gp', 'gc', 'adj', 'cash', 'debts', 'recv', 'tx', 'cos', 'res', 'tp', 'pmode', 'trash', 'locks', 'lockSnap'];

  Future<void> save({String? log}) async {
    if (kHakim && _prev != null) {
      final a = jsonDecode(_prev!) as Map<String, dynamic>;
      final b = jsonDecode(_snap()) as Map<String, dynamic>;
      final bad = _hkLocked.where((k) => jsonOut(a[k]) != jsonOut(b[k])).toList();
      if (bad.isNotEmpty) {
        for (final k in bad) { if (a.containsKey(k)) { S[k] = a[k]; } else { S.remove(k); } }
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _roT > 3000) { _roT = now; onMsg?.call('👁 النسخة دي للعرض بس — التعديل مسموح في «العقود» و«الأبديت» بس'); }
        if (_snap() == _prev) { notifyListeners(); return; }
      }
    }
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
    if (kHakim) pushHakimCt();
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
      final same = cfg['repo'] == o['r'] && (kHakim || (cfg['path'] ?? 'book.json') == (o['p'] ?? 'book.json'));
      cfg = {'repo': o['r'], 'token': o['t'], 'path': kHakim ? 'hakim.json' : truthy(o['p']) ? o['p'] : 'book.json', 'g': o['g'] ?? '', 'u': o['u'] ?? '',
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
    if (kHakim) return _pullHakim();
    await pullHakimCt();
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
      exportHakim();
      return syncMsg = '✓ اترفعت ${_now()}';
    }
    if (r.statusCode == 409 || r.statusCode == 422) { cfg['dirty'] = true; syncing = false; return await sync(); }
    return syncMsg = '✗ ${r.statusCode}';
  }

  /* ───── نسخة حكيم ───── */
  /// نسخة حكيم: بتنزّل hakim.json وبس (اللي برنامج أسامه بيبعته) — مفيش رفع
  Future<String> _pullHakim() async {
    syncing = true; notifyListeners();
    try {
      final r = await http.get(_u(get: true), headers: _h());
      if (r.statusCode == 404) return syncMsg = '⏳ أسامه لسه مابعتش الأرقام';
      if (r.statusCode == 401 || r.statusCode == 403) return syncMsg = '✗ الكود مش شغال — اطلب كود جديد من أسامه';
      if (r.statusCode != 200) return syncMsg = '✗ ${r.statusCode}';
      final j = jsonDecode(r.body) as Map; final sha = str(j['sha']);
      if (sha == cfg['sha'] && !(lst(S['units']).isEmpty)) return syncMsg = '✓ ${_now()}';
      Map<String, dynamic> rem;
      if ((j['content'] == null || str(j['content']).isEmpty) && n0(j['size']) > 0) {
        final rr = await http.get(_u(get: true), headers: _h(acc: 'application/vnd.github.raw'));
        if (rr.statusCode != 200) return syncMsg = '✗ ${rr.statusCode}';
        rem = jsonDecode(utf8.decode(rr.bodyBytes));
      } else { rem = jsonDecode(utf8.decode(base64.decode(str(j['content']).replaceAll(RegExp(r'\s'), '')))); }
      // اللي حكيم ضافه عنده (تذكيرات، إعدادات) يفضل — الأرقام بتيجي من أسامه
      for (final k in ['rem', 'set', 'lang', 'flutLinked', 'sigs']) { if (S[k] != null && rem[k] == null) rem[k] = S[k]; }
      noAmr(rem);
      // العقود: عقد حكيم الحالي يفضل عنده، والأرشيف بيتدمج (الأحدث يكسب)
      if (S['ct'] != null) rem['ct'] = S['ct'];
      rem['ctArc'] = mergeArc(S['ctArc'], rem['ctArc']);
      await _adopt(rem, sha);
      return syncMsg = '✓ نزلت آخر أرقام من أسامه ${_now()}';
    } catch (_) { return syncMsg = '✗ مفيش نت؟'; }
    finally { syncing = false; await _saveCfg(); notifyListeners(); }
  }

  static final _hk = RegExp(r'عبد\s*الحكيم|حكيم');
  static final _amr = RegExp(r'عمرو');

  /// مجموعة عمرو مش بتظهر في نسخة حكيم (بحساباتها كلها)
  static void noAmr(Map<String, dynamic> o) {
    final bad = {for (final g in objs(o['groups'])) if (_amr.hasMatch(str(g['name']))) str(g['id'])};
    if (bad.isEmpty) return;
    final bu = {for (final u in objs(o['units'])) if (bad.contains(str(u['g']))) str(u['id'])};
    o['groups'] = [for (final g in objs(o['groups'])) if (!bad.contains(str(g['id']))) g];
    o['units'] = [for (final u in objs(o['units'])) if (!bad.contains(str(u['g']))) u];
    o['exp'] = [for (final x in objs(o['exp'])) if (!(truthy(x['u']) ? bu.contains(str(x['u'])) : bad.contains(str(x['g'])))) x];
    o['dep'] = [for (final x in objs(o['dep'])) if (!bu.contains(str(x['uid']))) x];
    o['adj'] = [for (final x in objs(o['adj'])) if (!bad.contains(str(x['g']))) x];
    for (final k in ['gp', 'gc']) { final m = obj(o[k]); if (m != null) { final c = Map<String, dynamic>.from(m); c.removeWhere((id, _) => bad.contains(id)); o[k] = c; } }
  }

  /// دمج أرشيف العقود من جهتين: نفس العقد ⇒ الأحدث (at) يكسب
  static List<dynamic> mergeArc(dynamic a, dynamic b) {
    final m = <String, Map>{};
    for (final x in [...objs(a), ...objs(b)]) { final id = str(x['id']); if (id.isEmpty) continue; final o = m[id]; if (o == null || n0(x['at']) > n0(o['at'])) m[id] = x; }
    final L = m.values.toList()..sort((x, y) => n0(y['c0'] ?? y['at']).compareTo(n0(x['c0'] ?? x['at'])));
    return L;
  }

  /* ───── عقود حكيم ⇄ برنامج أسامه (hakim-ct.json) ───── */
  Uri get _hkCtU => Uri.parse('https://api.github.com/repos/${cfg['repo']}/contents/hakim-ct.json');
  bool _hcBusy = false; String _hcLast = '';
  /// نسخة حكيم: بترفع العقود اللي عملها (العقود بس — مفيش حسابات)
  Future<void> pushHakimCt() async {
    if (!kHakim || !linked || _hcBusy) return;
    final arc = S['ctArc'] ?? [];
    final k = jsonOut(arc); if (k == _hcLast) return;
    _hcBusy = true;
    try {
      await Future.delayed(const Duration(seconds: 2));
      final r = await http.get(Uri.parse('$_hkCtU?t=${DateTime.now().millisecondsSinceEpoch}'), headers: _h());
      var sha = '';
      if (r.statusCode == 200) sha = str((jsonDecode(r.body) as Map)['sha']);
      final b = {'message': 'hakim contracts ${DateTime.now().toUtc().toIso8601String()}', 'content': base64.encode(utf8.encode(jsonOut({'ctArc': arc, 'at': DateTime.now().millisecondsSinceEpoch, 'by': 'hakim'})))};
      if (sha.isNotEmpty) b['sha'] = sha;
      final w = await http.put(_hkCtU, headers: {..._h(), 'Content-Type': 'application/json'}, body: jsonEncode(b));
      if (w.statusCode == 200 || w.statusCode == 201) _hcLast = k;
    } catch (_) {} finally { _hcBusy = false; }
  }
  String _hcSha = '';
  /// برنامج أسامه: بيسحب عقود حكيم ويضيفها لأرشيفه
  Future<void> pullHakimCt() async {
    if (kHakim || !linked) return;
    try {
      final r = await http.get(Uri.parse('$_hkCtU?t=${DateTime.now().millisecondsSinceEpoch}'), headers: _h());
      if (r.statusCode != 200) return;
      final j = jsonDecode(r.body) as Map; final sha = str(j['sha']);
      if (sha == _hcSha) return; _hcSha = sha;
      final o = jsonDecode(utf8.decode(base64.decode(str(j['content']).replaceAll(RegExp(r'\s'), '')))) as Map;
      final m = mergeArc(S['ctArc'], o['ctArc']);
      if (jsonOut(m) != jsonOut(S['ctArc'] ?? [])) { S['ctArc'] = m; await save(log: '📁 عقود من حكيم'); }
    } catch (_) {}
  }
  /// برنامج أسامه: بيبعت مجموعة حكيم بس لنسخة حكيم (hakim.json) — نفس اللي بنيان القديم بيعمله
  Future<void> exportHakim() async {
    if (kHakim || !linked || _hkBusy) return;
    final gs = [for (final g in objs(S['groups'])) if (_hk.hasMatch(str(g['name'])) && !_amr.hasMatch(str(g['name']))) g];
    if (gs.isEmpty) return;
    _hkBusy = true;
    try {
      final gid = {for (final g in gs) str(g['id'])};
      final U = [for (final u in objs(S['units'])) if (gid.contains(str(u['g']))) u];
      final ids = {for (final u in U) str(u['id'])};
      final gp = <String, dynamic>{}, gc = <String, dynamic>{};
      for (final g in gs) { final id = str(g['id']); gp[id] = obj(S['gp'])?[id] ?? []; gc[id] = obj(S['gc'])?[id] ?? 0; }
      final o = <String, dynamic>{
        'units': U, 'groups': gs,
        'exp': [for (final x in objs(S['exp'])) if (truthy(x['u']) ? ids.contains(str(x['u'])) : gid.contains(str(x['g']))) x],
        'dep': [for (final x in objs(S['dep'])) if (ids.contains(str(x['uid']))) x],
        'gp': gp, 'gc': gc, 'cos': S['cos'] ?? [], 'cash': 0, 'res': S['res'] ?? 0, 'tp': S['tp'], 'pmode': S['pmode'], 'debts': [], 'recv': [], 'tx': [],
        'adj': [for (final a in objs(S['adj'])) if (gid.contains(str(a['g']))) a],
        'ct': S['ct'], 'ctArc': S['ctArc'] ?? [],
      };
      final key = jsonOut([o['units'], o['gp'], o['exp'], o['dep'], o['adj'], [for (final g in gs) [g['id'], g['name'], g['n'], g['share']]], o['gc'], o['cos'], o['ct'], o['ctArc']]);
      final kh = '${key.length}:${key.hashCode}';
      if (_p.getString('bny_hkexp_k') == kh) return;
      final u = Uri.parse('https://api.github.com/repos/${cfg['repo']}/contents/hakim.json');
      final r = await http.get(Uri.parse('$u?t=${DateTime.now().millisecondsSinceEpoch}'), headers: _h());
      var sha = '';
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body) as Map; sha = str(j['sha']);
        try { final old = jsonDecode(utf8.decode(base64.decode(str(j['content']).replaceAll(RegExp(r'\s'), '')))) as Map; if (old['updx'] != null) o['updx'] = old['updx']; } catch (_) {}
      }
      o['hist'] = [{'id': 'exp${DateTime.now().millisecondsSinceEpoch}', 't': DateTime.now().millisecondsSinceEpoch, 'by': 'owner', 'd': 'تحديث من برنامج المالك', 'ch': '[]', 'rev': false, 'ev': false}];
      o['from'] = 'owner'; o['at'] = DateTime.now().millisecondsSinceEpoch;
      final b = {'message': 'hakim ${DateTime.now().toUtc().toIso8601String()}', 'content': base64.encode(utf8.encode(jsonOut(o)))};
      if (sha.isNotEmpty) b['sha'] = sha;
      final w = await http.put(u, headers: {..._h(), 'Content-Type': 'application/json'}, body: jsonEncode(b));
      if (w.statusCode == 200 || w.statusCode == 201) await _p.setString('bny_hkexp_k', kh);
    } catch (_) {} finally { _hkBusy = false; }
  }
  bool _hkBusy = false;

  /// كود ربط لنسخة حكيم (أسامه بيبعته لحكيم مرة واحدة)
  String hakimCode() {
    if (!linked) return '';
    final j = jsonOut({'r': cfg['repo'], 't': cfg['token'], 'p': 'hakim.json', 'g': cfg['g'] ?? '', 'u': 'hakim'});
    return 'BNYLINK-${base64Url.encode(utf8.encode(j)).replaceAll('=', '')}';
  }

  String _now() { final d = DateTime.now(); return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'; }
}
