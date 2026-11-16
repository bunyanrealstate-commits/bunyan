import 'package:flutter/material.dart';
import 'i18n.dart';
import '../core/store.dart';
import '../core/engine.dart';
import '../core/actions.dart';
import '../core/js.dart';
import 'theme.dart';
import 'shell.dart';
import 'dialogs.dart';

class ExpensesPage extends StatelessWidget {
  const ExpensesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final ws = Ws.I.resolve();
    final e = Engine(Store.I.S, WS: ws);
    final l = e.SE()..sort((a, b) => str(b['d']).compareTo(str(a['d'])));
    final total = l.fold(0.0, (s, x) => s + n0(x['a']) * (truthy(x['n']) ? n(x['n']) : 1));
    return Stack(children: [
      ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 90), children: [
        Card(child: ListTile(title: Text(Tr.t('إجمالي المصاريف')), trailing: Text(money(total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: kRed)))),
        if (l.isEmpty) Padding(padding: EdgeInsets.all(30), child: Text(Tr.t('مفيش مصاريف'), textAlign: TextAlign.center)),
        for (final x in l) Card(child: ListTile(
          title: Text(str(x['w']).isEmpty ? Tr.t('مصروف') : str(x['w']), style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${str(x['d'])}${truthy(x['u']) ? '  •  ${Priv.un(e.U(x['u'])?['name'])}' : ''}${n0(x['n']) > 1 ? '  •  يتكرر ${str(x['n'])} شهور' : ''}'),
          trailing: Text(money(n0(x['a'])), style: const TextStyle(fontWeight: FontWeight.bold)),
          onTap: () => edit(context, x),
          onLongPress: () async {
            if (!await lockOk(context, [str(x['d'])]) || !context.mounted) return;
            if (await confirmDlg(context, 'مسح مصروف «${str(x['w'])}»؟ (هيروح لسلة المحذوفات 30 يوم)', ok: Tr.t('مسح'))) await Act.delExp(x, ws);
          },
        )),
        if (l.isNotEmpty) Padding(padding: EdgeInsets.all(8), child: Text(Tr.t('دوس على المصروف تعدّله — ودوس مطوّل تمسحه'), textAlign: TextAlign.center, style: TextStyle(color: kMuted, fontSize: 12))),
      ]),
      Positioned(left: 16, bottom: 16, child: FloatingActionButton.extended(onPressed: () => edit(context, null), icon: const Icon(Icons.add), label: Text(Tr.t('مصروف')))),
    ]);
  }

  static Future<void> edit(BuildContext c, Obj? x, {String unitId = ''}) async {
    final o = await formDlg(c, x == null ? (unitId.isNotEmpty ? Tr.t('مصروف على الاستديو') : Tr.t('مصروف')) : Tr.t('تعديل مصروف'), [
      FieldSpec('w', Tr.t('البيان (صيانة، كهرباء، عمولة...)'), v: x?['w'] ?? ''),
      FieldSpec('a', Tr.t('المبلغ'), type: 'n', v: x == null ? '' : str(x['a'])),
      FieldSpec('d', Tr.t('التاريخ'), type: 'd', v: x?['d'] ?? Act.td()),
      FieldSpec('n', Tr.t('عدد مرات التكرار شهرياً (1 = مرة واحدة)'), type: 'n', v: x == null ? '1' : str(x['n'] ?? 1)),
    ]);
    if (o == null) return;
    final a = double.tryParse(o['a'] ?? '') ?? 0; final nn = int.tryParse(o['n'] ?? '') ?? 1;
    if (x == null) { await Act.addExp(w: o['w'] ?? '', a: a, d: o['d'] ?? Act.td(), nn: nn < 1 ? 1 : nn, unitId: unitId, ws: Ws.I.resolve()); }
    else {
      if (!c.mounted || !await lockOk(c, [str(x['d']), o['d'] ?? ''])) return;
      await Act.editExp(x, w: o['w'] ?? '', a: a, d: o['d'] ?? Act.td(), nn: nn < 1 ? 1 : nn);
    }
  }
}
