/// حفظ البيانات على الموبايل + نسخة احتياطية في نفس ريبو بنيان (offers.json) لو اتربط
import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'model.dart';
import 'reqs.dart';

class Store extends ChangeNotifier {
  static final I = Store._();
  Store._();
  Obj D = {'villas': <dynamic>[]};
  Map<String, dynamic> cfg = {};
  bool loaded = false, testMode = false;
  SharedPreferences? _p;
  Timer? _bk;
  String backupMsg = '';

  List<Obj> get villas => objs(D['villas']);
  Obj? villa(String id) => villas.where((v) => v['id'] == id).firstOrNull;
  bool get linked => str(cfg['token']).isNotEmpty && str(cfg['repo']).isNotEmpty;
  String get gemKey { final g = cfg['g']; if (g is Map) return str(g['key']); final s = str(g); if (s.startsWith('{')) { try { return str((jsonDecode(s) as Map)['key']); } catch (_) {} } return s.startsWith('AIza') ? s : ''; }

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    try { cfg = (jsonDecode(_p!.getString('of_cfg') ?? '{}') as Map).cast<String, dynamic>(); } catch (_) {}
    String? raw;
    if (kIsWeb) { raw = _p!.getString('of_data'); } else { try { final f = await _file(); if (await f.exists()) raw = await f.readAsString(); } catch (_) {} }
    if (raw != null && raw.isNotEmpty) { try { D = (jsonDecode(raw) as Map).cast<String, dynamic>(); } catch (_) {} }
    // مرة واحدة: أسامه طلب يشيل شقق Yellow Line (كانت اتقرت غلط)
    if (cfg['mig_yl1'] != true) {
      final l = (D['villas'] as List?) ?? [];
      final before = l.length;
      l.removeWhere((v) => '${(v as Map)['company']} ${v['name']}'.toLowerCase().contains('yellow line'));
      cfg['mig_yl1'] = true; await saveCfg();
      if (l.length != before) await save();
    }
    // مرة واحدة: طلبات غلط اتعملت من إشعارات الواتساب نفسه (Sending video…)
    if (cfg['mig_req1'] != true) {
      final l = (D['reqs'] as List?) ?? [];
      final before = l.length;
      l.removeWhere((r) { final m = r as Map; final n = '${m['n']}'.toLowerCase(); return n == 'whatsapp business' || n == 'whatsapp' || '${m['txt']}'.trimLeft().startsWith('Sending'); });
      cfg['mig_req1'] = true; await saveCfg();
      if (l.length != before) await save();
    }
    // مرة واحدة: العملاء = أسامي جهات الاتصال اللي بصيغة «Studio Fur 3500 Suzanne» بس — والباقي يتلغى
    if (cfg['mig_req2'] != true) {
      final l = (D['reqs'] as List?) ?? [];
      l.removeWhere((r) { final m = r as Map; return m['src'] != 'contact' || parseContactName('${m['cn'] ?? m['txt'] ?? ''}') == null; });
      cfg['dm'] = false; cfg['mig_req2'] = true; await saveCfg();
      await save();
    }
    // مرة واحدة: نعيد فهم أسامي العملاء (40 = 40 ألف، Khalifa مش «k»، ديسمبر = ميعاد السكن)
    if (cfg['mig_req3'] != true) {
      for (final r in ((D['reqs'] as List?) ?? []).whereType<Map>()) {
        if (r['src'] != 'contact') continue;
        final cn = '${r['cn'] ?? r['txt'] ?? ''}';
        final q = parseContactName(cn);
        if (q == null) continue;
        for (final k in ['types', 'budget', 'pay', 'fur', 'when']) { r[k] = q[k]; }
        r['n'] = q['name']; r['cn'] = cn;
      }
      cfg['mig_req3'] = true; await saveCfg();
      await save();
    }
    loaded = true; notifyListeners();
    if (villas.isEmpty && linked) await restore();
  }
  Future<void> initTest(Obj d) async { _p = await SharedPreferences.getInstance(); D = d; cfg = {}; loaded = true; testMode = true; }

  Future<File> _file() async => File('${(await getApplicationDocumentsDirectory()).path}/offers.json');
  void notify() => notifyListeners();
  Future<void> saveCfg() async => _p?.setString('of_cfg', jsonEncode(cfg));

  Future<void> save() async {
    D['at'] = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    if (testMode) return;
    final t = jsonEncode(D);
    if (kIsWeb) { await _p?.setString('of_data', t); } else { final f = await _file(); await f.writeAsString(t, flush: true); }
    _bk?.cancel(); _bk = Timer(const Duration(seconds: 8), backup);
  }

  /// كود الربط من بنيان (BNYLINK-…): فيه مفتاح Gemini وريبو الباك أب
  bool link(String code) {
    final m = RegExp(r'BNYLINK-([A-Za-z0-9_-]+)').firstMatch(code.replaceAll(RegExp(r'\s+'), ''));
    if (m == null) return false;
    var s = m[1]!.replaceAll('-', '+').replaceAll('_', '/'); while (s.length % 4 != 0) { s += '='; }
    try {
      final o = jsonDecode(utf8.decode(base64.decode(s))) as Map;
      cfg['repo'] = o['r'] ?? cfg['repo']; cfg['token'] = o['t'] ?? cfg['token']; if (o['g'] != null && str(o['g']).isNotEmpty) cfg['g'] = o['g'];
      saveCfg(); notifyListeners(); return true;
    } catch (_) { return false; }
  }

  Map<String, String> get gh => _h;
  Map<String, String> get _h => {'Authorization': 'Bearer ${cfg['token']}', 'Accept': 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28'};
  Uri get _u => Uri.parse('https://api.github.com/repos/${cfg['repo']}/contents/offers.json');

  Future<void> backup() async {
    if (!linked || testMode) return;
    try {
      String? sha; final g = await http.get(Uri.parse('$_u?t=${DateTime.now().millisecondsSinceEpoch}'), headers: _h).timeout(const Duration(seconds: 20));
      if (g.statusCode == 200) sha = str(jsonDecode(g.body)['sha']);
      final r = await http.put(_u, headers: _h, body: jsonEncode({'message': '🏡 offers backup', 'content': base64.encode(utf8.encode(jsonEncode(D))), if (sha != null) 'sha': sha})).timeout(const Duration(seconds: 30));
      backupMsg = (r.statusCode == 200 || r.statusCode == 201) ? '☁️ آخر باك أب: ${DateTime.now().toString().substring(0, 16)}' : '⚠️ الباك أب ما نجحش (${r.statusCode})';
    } catch (_) { backupMsg = '⚠️ مفيش نت — الباك أب هيتعمل بعدين'; }
    notifyListeners();
  }

  Future<bool> restore() async {
    if (!linked) return false;
    try {
      final g = await http.get(Uri.parse('$_u?t=${DateTime.now().millisecondsSinceEpoch}'), headers: _h).timeout(const Duration(seconds: 25));
      if (g.statusCode != 200) return false;
      final x = jsonDecode(utf8.decode(base64.decode(str(jsonDecode(g.body)['content']).replaceAll('\n', '')))) as Map;
      if (objs(x['villas']).isEmpty) return false;
      D = x.cast<String, dynamic>(); await save(); return true;
    } catch (_) { return false; }
  }
}
