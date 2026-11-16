import 'package:flutter/material.dart';
import 'i18n.dart';
import '../core/store.dart';
import '../core/monitor.dart';
import '../core/actions.dart';
import '../core/js.dart';
import 'theme.dart';
import 'dialogs.dart';

/// 🛡 المراقب + 👎 مش عاجبني (الشكاوى بتتحفظ في S.complaints وتوصل للمراقب في القديم)
class MonitorPage extends StatefulWidget {
  const MonitorPage({super.key});
  @override
  State<MonitorPage> createState() => _MonState();
}

class _MonState extends State<MonitorPage> {
  Obj get S => Store.I.S;
  @override
  Widget build(BuildContext context) {
    final r = Mon.run(S);
    final fx = objs(S['monfix']).toList().reversed.take(30).toList();
    final cp = objs(S['complaints']).toList().reversed.take(30).toList();
    return Directionality(textDirection: L.dir, child: Scaffold(
      appBar: AppBar(title: Text(L.t('🛡 المراقب'))),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => complain(context, L.t('المراقب')), icon: const Text('👎'), label: Text(L.t('مش عاجبني حاجة'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
        Card(color: r.isEmpty ? const Color(0xFFE6F4EC) : const Color(0xFFFFF7E6), child: ListTile(title: Text(r.isEmpty ? L.t('✅ البيانات سليمة — مفيش مشاكل') : '⚠️ فيه ${r.length} حاجة محتاجة تتبص'), subtitle: Text('${Mon.rules.length} قاعدة فحص'))),
        for (final x in r) Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${(x['rule'] as MonRule).area}: ${(x['rule'] as MonRule).t}', style: const TextStyle(fontWeight: FontWeight.w900)),
          for (final f in (x['f'] as List<String>).take(6)) Text('• $f', style: const TextStyle(color: kMuted)),
          if ((x['rule'] as MonRule).fix != null) Align(alignment: Alignment.centerLeft, child: FilledButton(onPressed: () async {
            if (!await confirmDlg(context, L.t('أصلّحها؟ (تقدر تتراجع من سجل النشاط)'), ok: L.t('صلّح'))) return;
            final how = Mon.fix(S, x['rule'] as MonRule, x['f'] as List<String>);
            await Store.I.save(log: '🛡 المراقب: $how');
            if (context.mounted) { toast(context, '✅ $how'); setState(() {}); }
          }, child: Text(L.t('🔧 صلّح')))) else Text(L.t('(بتتصلح بإيدك)'), style: TextStyle(fontSize: 12, color: kMuted)),
        ]))),
        if (cp.isNotEmpty) Padding(padding: EdgeInsets.only(top: 12, bottom: 4), child: Text(L.t('👎 شكاويك'), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
        for (final c in cp) Card(child: ListTile(dense: true, title: Text(str(c['txt'])), subtitle: Text('${c['st'] == 'fixed' ? '✅ اتصلحت' : '⏳ مستنية'}${truthy(c['why']) ? ' — ${c['why']}' : ''}', maxLines: 3, overflow: TextOverflow.ellipsis))),
        if (fx.isNotEmpty) Padding(padding: EdgeInsets.only(top: 12, bottom: 4), child: Text(L.t('🔧 آخر التصليحات'), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
        for (final f in fx) ListTile(dense: true, title: Text(str(f['why']), maxLines: 2, overflow: TextOverflow.ellipsis), subtitle: Text('${str(f['how'])} • ${iso(DateTime.fromMillisecondsSinceEpoch(n0(f['at']).toInt()))}', maxLines: 2, overflow: TextOverflow.ellipsis)),
      ]),
    ));
  }
}

Future<void> complain(BuildContext context, String tab) async {
  final o = await formDlg(context, L.t('👎 مش عاجبني حاجة'), [FieldSpec('t', L.t('اكتب إيه اللي مش عاجبك (شكل، رقم غلط، حاجة ناقصة…)'))]);
  final t = (o?['t'] ?? '').trim(); if (t.isEmpty) return;
  final S = Store.I.S; final l = lst(S['complaints']).toList();
  l.add({'id': Act.uid(), 'at': Act.now(), 'tab': 'flutter/$tab', 'txt': t, 'st': 'new'}); S['complaints'] = l;
  await Store.I.save(log: '👎 شكوى: $t');
  if (context.mounted) toast(context, L.t('📨 اتبعتت للمراقب — هتتصلح وتبقى قاعدة'));
}

/// كارت صغير في الداشبورد — بيظهر بس لو فيه مشكلة
class MonBanner extends StatelessWidget {
  const MonBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final r = Mon.run(Store.I.S); if (r.isEmpty) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Card(color: const Color(0xFFFFF7E6), child: ListTile(leading: const Text('🛡', style: TextStyle(fontSize: 22)), title: Text('المراقب لقى ${r.length} حاجة محتاجة تتصلح'), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MonitorPage())))));
  }
}
