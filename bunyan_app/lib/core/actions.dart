/// كل التعديلات على البيانات — مكتوبة بنفس شكل بنيان القديم بالظبط علشان الاتنين يفهموا نفس الملف
import 'dart:math' as math;
import 'engine.dart';
import 'js.dart';
import 'store.dart';

class Act {
  static Map<String, dynamic> get S => Store.I.S;
  static final _rnd = math.Random();
  /// زي uid() في القديم: 7 حروف
  static String uid() { const a = '0123456789abcdefghijklmnopqrstuvwxyz'; return List.generate(7, (_) => a[_rnd.nextInt(36)]).join(); }
  static String td() => iso(today());
  static int now() => DateTime.now().millisecondsSinceEpoch;

  static Obj? unit(String id) => objs(S['units']).where((u) => u['id'] == id).firstOrNull;
  static bool isLk(dynamic d) => truthy(d) && lst(S['locks']).map(str).contains(str(d).substring(0, math.min(7, str(d).length)));

  static Map<String, dynamic> _m(dynamic v) => v is Map<String, dynamic> ? v : <String, dynamic>{};
  static Map<String, dynamic> _ensureMap(Obj o, String k) { final v = o[k]; if (v is Map<String, dynamic>) return v; final m = <String, dynamic>{}; o[k] = m; return m; }
  static List<dynamic> _ensureList(Obj o, String k) { final v = o[k]; if (v is List) return v; final l = <dynamic>[]; o[k] = l; return l; }

  /* ───── تحصيل الإيجار ───── */
  static Future<void> rentPaid(Obj u, int k, int i) async {
    final L = objs(u['leases'])[k];
    final r = _ensureList(L, 'rcv');
    if (r.map((e) => n(e).toInt()).contains(i)) return;
    final a = Engine.la(L, i);
    r.add(i); r.sort((x, y) => n(x).compareTo(n(y)));
    _ensureMap(L, 'rat')['$i'] = now(); _ensureMap(L, 'rav')['$i'] = _num(a);
    await Store.I.save(log: '✅ استلمت ${_fmt(a)} من ${str(L['tenant']).isEmpty ? 'المستأجر' : str(L['tenant'])} — ${str(u['name'])} (دفعة ${i + 1})');
  }
  static Future<void> rentUnpaid(Obj u, int k, int i) async {
    final L = objs(u['leases'])[k];
    final r = _ensureList(L, 'rcv');
    r.removeWhere((e) => n(e).toInt() == i);
    _m(L['rat']).remove('$i'); _m(L['rav']).remove('$i');
    await Store.I.save(log: '↩️ لغيت استلام دفعة ${i + 1} — ${str(L['tenant'])} — ${str(u['name'])}');
  }

  /* ───── دفعات الشركة ───── */
  /// src: '' = من بره البرنامج، 'cash' = من الرصيد، 'gp' = من فلوس الشراكة
  static Future<void> instPay(Obj u, int k, String src) async {
    final i = objs(u['inst'])[k];
    i['p'] = true; i['at'] = src == 'cash' ? now() : 0;
    if (src == 'gp') { i['gid'] = truthy(i['gid']) ? i['gid'] : uid(); gpPay(str(u['g']), 'i${i['gid']}', -n(i['a']), 'دفعة ${str(u['company']).isEmpty ? 'الشركة' : str(u['company'])} — ${str(u['name'])}'); }
    await Store.I.save(log: '💳 دفعت ${_fmt(n(i['a']))} لـ${str(u['company'])} — ${str(u['name'])}');
  }
  static Future<void> instUnpay(Obj u, int k) async {
    final i = objs(u['inst'])[k];
    i['p'] = false; i['at'] = 0; gpRm(str(u['g']), 'i${str(i['gid'])}');
    await Store.I.save(log: '↩️ لغيت دفعة الشركة — ${str(u['name'])}');
  }
  static bool gpOK(Obj u) => objs(S['groups']).any((g) => g['id'] == u['g']);
  static void gpRm(String gid, String key) { final gp = S['gp']; if (gp is! Map || gp[gid] is! List) return; gp[gid] = (gp[gid] as List).where((x) => !(x is Map && x['key'] == key)).toList(); }
  static void gpPay(String gid, String key, double a, String w) {
    if (gid.isEmpty) return;
    final gp = _ensureMap(S, 'gp'); if (gp[gid] is! List) gp[gid] = <dynamic>[];
    gpRm(gid, key); (gp[gid] as List).add({'id': uid(), 'd': td(), 'a': _num(a), 'w': w, 'key': key});
  }

  /* ───── المصاريف ───── */
  static Future<void> addExp({required String w, required double a, required String d, int nn = 1, String unitId = '', required String ws}) async {
    final l = _ensureList(S, 'exp');
    l.add({'id': uid(), 'u': unitId, 'g': (unitId.isNotEmpty || ws == 'all' || ws == '-') ? '' : ws, 'w': w, 'a': _num(a), 'd': d, 'n': nn});
    await Store.I.save(log: '🧾 مصروف: $w — ${_fmt(a)}');
  }
  static Future<void> editExp(Obj x, {required String w, required double a, required String d, int nn = 1}) async {
    x['w'] = w; x['a'] = _num(a); x['d'] = d; x['n'] = nn;
    await Store.I.save(log: '✏️ عدّلت مصروف: $w');
  }
  static Future<void> delExp(Obj x, String ws) async {
    final l = _ensureList(S, 'exp'); final i = l.indexOf(x); if (i < 0) return;
    l.removeAt(i);
    toTrash([{'c': 'exp', 'i': i, 'o': x}], 'مصروف «${str(x['w'])}»', ws);
    await Store.I.save(log: '🗑 مسحت مصروف: ${str(x['w'])}');
  }

  /* ───── سلة المحذوفات (نفس شكل القديم) ───── */
  static void toTrash(List<Map<String, dynamic>> parts, String label, String ws) {
    final lim = now() - 30 * 864e5;
    final t = lst(S['trash']).where((x) => n0(obj(x)?['at']) > lim).toList();
    t.add({'id': uid(), 'at': now(), 'l': label, 'g': ws, 'p': parts});
    S['trash'] = t.length > 60 ? t.sublist(t.length - 60) : t;
  }

  /* ───── وقف العقد / الاستئناف / الشرط الجزائي (mStop/resumeL/togPen) ───── */
  static Future<void> stopLease(Obj u, int k, String exit, double pen, bool penp) async {
    final L = objs(u['leases'])[k];
    final orig = truthy(L['orig']) ? n(L['orig']).toInt() : Engine.months(L); var c = 0;
    for (var i = 0; i < orig; i++) { if (!Engine.payD(L, i).isAfter(pd(exit))) c++; }
    L['orig'] = orig; L['exit'] = exit; final p = pen < 0 ? 0.0 : pen; L['pen'] = _num(p); L['penp'] = p > 0 && penp; L['months'] = c;
    L['rcv'] = lst(L['rcv']).where((i) => n(i) < c).toList(); L['pp'] = objs(L['pp']).where((x) => n(x['i']) < c).toList();
    final rat = _ensureMap(L, 'rat'), rav = _ensureMap(L, 'rav'); final rc = Engine.rcv(L);
    for (final q in rat.keys.toList()) { if (!rc.contains(int.tryParse(q) ?? -1)) { rat.remove(q); rav.remove(q); } }
    L['pat'] = L['penp'] == true ? (truthy(L['pat']) ? L['pat'] : now()) : 0;
    await Store.I.save(log: '⛔ وقفت عقد ${str(L['tenant'])} — ${str(u['name'])} من $exit');
  }
  static Future<void> resumeLease(Obj u, int k) async {
    final L = objs(u['leases'])[k];
    L['months'] = truthy(L['orig']) ? L['orig'] : L['months']; L['exit'] = ''; L['pen'] = 0; L['penp'] = false; L['pat'] = 0;
    await Store.I.save(log: '▶️ استأنفت عقد ${str(L['tenant'])} — ${str(u['name'])}');
  }
  static Future<void> togPen(Obj u, int k) async {
    final L = objs(u['leases'])[k]; L['penp'] = !truthy(L['penp']); L['pat'] = L['penp'] == true ? now() : 0;
    await Store.I.save(log: '💰 ${L['penp'] == true ? 'استلمت' : 'لغيت استلام'} الشرط الجزائي — ${str(L['tenant'])}');
  }

  /* ───── الحذف (بيروح لسلة المحذوفات زي القديم) ───── */
  static Future<void> delLease(Obj u, int k, String ws) async {
    final ls = u['leases'] as List; final L = ls[k] as Obj;
    ls.removeAt(k);
    toTrash([{'c': 'units.leases', 'u': u['id'], 'un': u['name'], 'k': k, 'o': L}], 'عقد مستأجر «${str(L['tenant'])}» — ${str(u['name'])}', ws);
    await Store.I.save(log: '🗑 حذفت عقد ${str(L['tenant'])} — ${str(u['name'])}');
  }
  static Future<void> delUnit(Obj u, String ws) async {
    final id = u['id']; final nm = str(u['name']); final lids = objs(u['leases']).map((l) => l['id']).toList();
    final gk = <String>[for (final i in objs(u['inst'])) if (truthy(i['gid'])) 'i${i['gid']}', 'f$id', 'c$id'];
    final parts = <Map<String, dynamic>>[];
    void rm(String c, bool Function(Obj) drop) {
      final l = lst(S[c]).toList(); final keep = <dynamic>[];
      for (var i = 0; i < l.length; i++) { final x = obj(l[i]); if (x != null && drop(x)) { parts.add({'c': c, 'i': i, 'o': x}); } else { keep.add(l[i]); } }
      if (S.containsKey(c) || keep.isNotEmpty) S[c] = keep;
    }
    rm('units', (x) => x['id'] == id);
    rm('exp', (x) => x['u'] == id);
    rm('tx', (x) => x['u'] == id);
    rm('adj', (x) => x['u'] == id || ((x['g'] == str(u['g']) || x['g'] == null) && x['w'] is String && str(x['w']).startsWith('تمويل ') && str(x['w']).contains(' $nm من أموالي')));
    rm('dep', (x) => x['uid'] == id || lids.contains(x['lid']));
    for (final a in objs(S['adj'])) {
      if (truthy(a['ref']) && gk.contains(a['ref']) && truthy(a['gcAdj'])) {
        if (truthy(u['g'])) { final gc = _ensureMap(S, 'gc'); gc[str(u['g'])] = _num(n0(gc[str(u['g'])]) + n(a['gcAdj'])); } else { S['cash'] = _num(n0(S['cash']) + n(a['gcAdj'])); }
      }
    }
    rm('adj', (x) => truthy(x['ref']) && gk.contains(x['ref']));
    final gp = S['gp']; if (gp is Map) { for (final g in gp.keys.toList()) { gp[g] = lst(gp[g]).where((x) => !(x is Map && (gk.contains(x['key']) || x['w'] == 'فلوس شراكة لـ $nm'))).toList(); } }
    toTrash(parts, 'استديو «$nm»${parts.length > 1 ? ' (+${parts.length - 1})' : ''}', ws);
    await Store.I.save(log: '🗑 حذفت الاستديو $nm');
  }

  /// الأرقام الصحيحة تتكتب int (زي JS)
  static num _num(double v) => v == v.roundToDouble() && v.abs() < 9e15 ? v.toInt() : v;
  static String _fmt(double v) { final r = v.round(); final s = r.abs().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ','); return r < 0 ? '-$s' : s; }
}
