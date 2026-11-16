import 'package:flutter/material.dart';
import 'i18n.dart';
import '../core/store.dart';
import '../core/engine.dart';
import '../core/actions.dart';
import '../core/js.dart';
import 'theme.dart';
import 'dialogs.dart';
import 'shell.dart';

/// الشيكات اللي معايا — نفس chqList/chqCard/mChq في القديم (للعلم فقط، مش بتغيّر الحسابات)
class Chq {
  static List<Map<String, dynamic>> list(Obj L) {
    final c = L['chq'];
    if (c == null || c == false) return [];
    if (c is List) return c.whereType<Map<String, dynamic>>().toList();
    if (c is Map) {
      final r = [for (final q in c.keys) {'no': str(obj(c[q])?['no']), 'd': iso(Engine.payD(L, int.tryParse('$q') ?? 0)), 'a': Engine.la(L, int.tryParse('$q') ?? 0).round()}];
      r.sort((a, b) => str(a['d']).compareTo(str(b['d'])));
      return r;
    }
    return [];
  }

  /// q = null → شيك جديد
  static Future<void> edit(BuildContext context, Obj L, int? q) async {
    final l = list(L); L['chq'] = l;
    final c = q == null ? {'no': '', 'd': Act.td(), 'a': (n0(L['rent']) + n0(L['inet'])).round()} : l[q];
    final r = await formDlg(context, '${q == null ? 'شيك جديد' : 'شيك'} — ${str(L['tenant']).isEmpty ? 'مستأجر' : str(L['tenant'])}', [
      FieldSpec('no', L.t('رقم الشيك'), v: str(c['no'])),
      FieldSpec('d', L.t('التاريخ'), type: 'd', v: truthy(c['d']) ? str(c['d']) : Act.td()),
      FieldSpec('a', L.t('المبلغ'), type: 'n', v: n0(c['a']) == n0(c['a']).roundToDouble() ? n0(c['a']).toInt() : n0(c['a'])),
    ]);
    if (r == null) return;
    final a = double.tryParse(r['a'] ?? '') ?? 0;
    final x = {'no': (r['no'] ?? '').trim(), 'd': truthy(r['d']) ? r['d'] : Act.td(), 'a': a == a.roundToDouble() ? a.toInt() : a};
    if (q == null) { l.add(x); } else { l[q] = x; }
    l.sort((a, b) => str(a['d']).compareTo(str(b['d'])));
    await Store.I.save(log: '📑 ${q == null ? 'شيك جديد' : 'عدّلت شيك'} — ${str(L['tenant'])}');
  }

  static Future<void> del(BuildContext context, Obj L, int q) async {
    if (!await confirmDlg(context, L.t('تمسح الشيك ده؟'), ok: L.t('امسح'))) return;
    final l = list(L); l.removeAt(q); L['chq'] = l;
    await Store.I.save(log: '🗑 مسحت شيك — ${str(L['tenant'])}');
  }
}

class ChequesPage extends StatelessWidget {
  const ChequesPage({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: Store.I, builder: (context, _) {
      final e = Engine(Store.I.S, WS: Ws.I.resolve());
      final R = <Map<String, dynamic>>[];
      for (final u in e.SU()) { final ls = objs(u['leases']); for (var k = 0; k < ls.length; k++) { final cl = Chq.list(ls[k]); for (var q = 0; q < cl.length; q++) { R.add({'u': u, 'L': ls[k], 'q': q, 'c': cl[q]}); } } }
      R.sort((a, b) => str((a['c'] as Map)['d']).compareTo(str((b['c'] as Map)['d'])));
      final sc = objs(Store.I.S['dep']).where((x) => x['mode'] == 'chq' && !truthy(x['r'])).toList();
      final td = Act.td();
      return Directionality(textDirection: L.dir, child: Scaffold(
        appBar: AppBar(title: Text(L.t('📑 الشيكات اللي معايا'))),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          Text(L.t('للعلم فقط: الشيك ضمان لالتزام المستأجر بالدفع، ومش بيغيّر الحسابات. دوس على الشيك تعدّله، ودوس مطوّل تمسحه.'), style: TextStyle(color: kMuted)),
          const SizedBox(height: 8),
          Card(child: ListTile(title: Text('شيكات الإيجار: ${R.length}'), subtitle: Text(money(R.fold<double>(0, (s, x) => s + n0((x['c'] as Map)['a'])))))),
          if (sc.isNotEmpty) Card(child: ListTile(title: Text('شيكات التأمين: ${sc.length}'), subtitle: Text(money(sc.fold<double>(0, (s, x) => s + n0(x['a'])))))),
          for (final x in R.take(200)) Card(child: ListTile(
            dense: true,
            leading: Text(str((x['c'] as Map)['d']).compareTo(td) <= 0 ? '🟢' : '📑'),
            title: Text('${str((x['L'] as Obj)['tenant']).isEmpty ? 'مستأجر' : str((x['L'] as Obj)['tenant'])} • ${str((x['u'] as Obj)['name'])}'),
            subtitle: Text('${str((x['c'] as Map)['no']).isEmpty ? '' : 'رقم ${(x['c'] as Map)['no']} • '}${(x['c'] as Map)['d']}'),
            trailing: Text(money(n0((x['c'] as Map)['a'])), style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: () => Chq.edit(context, x['L'] as Obj, x['q'] as int),
            onLongPress: () => Chq.del(context, x['L'] as Obj, x['q'] as int),
          )),
          for (final d in sc) Card(child: ListTile(dense: true, leading: const Text('🔐'), title: Text('شيك ضمان — ${str(d['w'])}'), subtitle: Text(str(d['no'])), trailing: Text(money(n0(d['a']))))),
        ]),
      ));
    });
  }
}
