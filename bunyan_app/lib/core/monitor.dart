/// 🛡 المراقب — فحص سلامة البيانات (نفس فكرة monrules: كل قاعدة check + fix) على البيانات نفسها
import 'js.dart';
import 'engine.dart';

class MonRule {
  final String id, area, t; final List<String> Function(Obj S) check; final String Function(Obj S)? fix;
  const MonRule(this.id, this.area, this.t, this.check, this.fix);
}

class Mon {
  static Set<dynamic> _uids(Obj S) => objs(S['units']).map((u) => u['id']).toSet();
  static final rules = <MonRule>[
    MonRule('orphexp', 'المصاريف', 'مصروف مربوط باستديو اتحذف', (S) { final ids = _uids(S); return [for (final x in objs(S['exp'])) if (truthy(x['u']) && !ids.contains(x['u'])) 'مصروف «${str(x['w'])}» ${str(x['a'])}']; },
      (S) { final ids = _uids(S); final l = lst(S['exp']); final b = l.length; S['exp'] = l.where((x) => !(x is Map && truthy(x['u']) && !ids.contains(x['u']))).toList(); return 'اتشال ${b - lst(S['exp']).length} مصروف يتيم'; }),
    MonRule('orphdep', 'التأمينات', 'تأمين لاستديو اتحذف', (S) { final ids = _uids(S); return [for (final x in objs(S['dep'])) if (truthy(x['uid']) && !ids.contains(x['uid'])) 'تأمين «${str(x['w'])}» ${str(x['a'])}']; },
      (S) { final ids = _uids(S); S['dep'] = lst(S['dep']).where((x) => !(x is Map && truthy(x['uid']) && !ids.contains(x['uid']))).toList(); return 'اتشالت التأمينات اليتيمة'; }),
    MonRule('orphadj', 'الحسابات', 'تمويل/حركة نقدي لاستديو اتحذف', (S) { final ids = _uids(S); return [for (final x in objs(S['adj'])) if (truthy(x['u']) && !ids.contains(x['u'])) str(x['w'])]; }, null),
    MonRule('rcvx', 'الإيجارات', 'إيجار متعلّم مستلم لشهر برّه مدة العقد', (S) => [for (final u in objs(S['units'])) for (final L in objs(u['leases'])) for (final i in Engine.rcv(L)) if (i >= Engine.months(L)) '${str(u['name'])} — ${str(L['tenant'])} (دفعة ${i + 1})'],
      (S) { for (final u in objs(S['units'])) { for (final L in objs(u['leases'])) { final m = Engine.months(L); L['rcv'] = lst(L['rcv']).where((i) => n(i) < m).toList(); } } return 'اتشالت الدفعات اللي برّه مدة العقد'; }),
    MonRule('ravx', 'الإيجارات', 'مبلغ مستلم متسجل لدفعة مش متعلّمة مستلمة', (S) => [for (final u in objs(S['units'])) for (final L in objs(u['leases'])) for (final k in (obj(L['rav']) ?? {}).keys) if (!Engine.rcv(L).contains(int.tryParse(k) ?? -1)) '${str(u['name'])} — ${str(L['tenant'])} (دفعة ${(int.tryParse(k) ?? 0) + 1})'],
      (S) { for (final u in objs(S['units'])) { for (final L in objs(u['leases'])) { final rc = Engine.rcv(L); for (final f in ['rav', 'rat']) { final m = obj(L[f]); if (m != null) m.removeWhere((k, _) => !rc.contains(int.tryParse(k) ?? -1)); } } } return 'اتنضفت المبالغ اليتيمة'; }),
    MonRule('dupid', 'الاستديوهات', 'استديوهين بنفس الرقم الداخلي', (S) { final seen = <dynamic>{}; final o = <String>[]; for (final u in objs(S['units'])) { if (!seen.add(u['id'])) o.add(str(u['name'])); } return o; }, null),
    MonRule('gpneg', 'المجموعات', 'فلوس الشراكة طالعة بالسالب', (S) { final o = <String>[]; final gp = obj(S['gp']) ?? {}; for (final g in objs(S['groups'])) { final t = lst(gp[g['id']]).fold<double>(0, (s, x) => s + n0(obj(x)?['a'])); if (t < -0.5) o.add('${str(g['name'])}: ${t.round()}'); } return o; }, null),
    MonRule('nodate', 'الدفعات', 'دفعة شركة من غير تاريخ', (S) => [for (final u in objs(S['units'])) for (final i in objs(u['inst'])) if (!truthy(i['d'])) '${str(u['name'])} — ${str(i['a'])}'], null),
  ];

  static List<Map<String, dynamic>> run(Obj S) {
    final r = <Map<String, dynamic>>[];
    for (final x in rules) { try { final f = x.check(S); if (f.isNotEmpty) r.add({'rule': x, 'f': f}); } catch (_) {} }
    return r;
  }

  /// بيسجّل التصليح في S.monfix زي القديم
  static String fix(Obj S, MonRule x, List<String> f) {
    final how = x.fix!(S);
    final l = lst(S['monfix']).toList();
    l.add({'id': DateTime.now().microsecondsSinceEpoch.toRadixString(36).substring(4), 'at': DateTime.now().millisecondsSinceEpoch, 'k': 'r:${x.id}', 'kind': x.area, 'why': x.t, 'how': how, 'd': f.take(5).toList(), 'auto': false, 'st': 'ok', 'res': '✅ اتصلح من بنيان الجديد'});
    S['monfix'] = l.length > 200 ? l.sublist(l.length - 200) : l;
    return how;
  }

  /// نفس bnyRulesSelfTest: كل قاعدة ليها تصليح لازم تمسك الغلط وتصلحه
  static List<String> selfTest() {
    final bad = <String>[];
    Obj mk() => {'units': [{'id': 'u1', 'name': 'A', 'leases': [{'tenant': 't', 'months': 2, 'rcv': [0, 5], 'rav': {'0': 1, '3': 9}, 'rat': {'3': 1}}], 'inst': []}], 'exp': [{'u': 'zz', 'w': 'x', 'a': 5}], 'dep': [{'uid': 'zz', 'w': 'd', 'a': 1}], 'adj': [], 'groups': [], 'gp': {}};
    for (final x in rules.where((x) => x.fix != null)) { final S = mk(); if (x.check(S).isEmpty) { bad.add('${x.id}: ما مسكش الغلط'); continue; } x.fix!(S); if (x.check(S).isNotEmpty) bad.add('${x.id}: ما صلّحش'); }
    return bad;
  }
}
