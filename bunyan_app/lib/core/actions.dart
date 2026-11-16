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

  /// الأرقام الصحيحة تتكتب int (زي JS)
  static num _num(double v) => v == v.roundToDouble() && v.abs() < 9e15 ? v.toInt() : v;
  static String _fmt(double v) { final r = v.round(); final s = r.abs().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ','); return r < 0 ? '-$s' : s; }
}
