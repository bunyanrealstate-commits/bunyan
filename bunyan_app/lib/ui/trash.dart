import 'package:flutter/material.dart';
import 'i18n.dart';
import '../core/store.dart';
import '../core/js.dart';
import 'theme.dart';
import 'dialogs.dart';

/// 🗑 سلة المحذوفات (30 يوم) — نفس بيانات القديم S.trash
class TrashPage extends StatefulWidget {
  const TrashPage({super.key});
  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  Map<String, dynamic> get S => Store.I.S;
  @override
  Widget build(BuildContext context) {
    final t = objs(S['trash']).reversed.toList();
    return Directionality(textDirection: L.dir, child: Scaffold(
      appBar: AppBar(title: Text(L.t('🗑 سلة المحذوفات'))),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Text(L.t('اللي بتمسحه بيفضل هنا 30 يوم وتقدر ترجعه.'), style: TextStyle(color: kMuted)),
        if (t.isEmpty) Padding(padding: EdgeInsets.all(30), child: Text(L.t('السلة فاضية'), textAlign: TextAlign.center)),
        for (final r in t) Card(child: ListTile(
          title: Text(str(r['l']), style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(DateTime.fromMillisecondsSinceEpoch(n0(r['at']).toInt()).toString().substring(0, 16)),
          trailing: TextButton(onPressed: () => _restore(r), child: Text(L.t('↩ رجّعه'))),
        )),
      ]),
    ));
  }

  Future<void> _restore(Obj r) async {
    final parts = objs(r['p']);
    for (final p in parts.reversed) {
      final c = str(p['c']); final o = p['o'];
      if (c == 'units.leases' || c == 'units.inst') {
        final u = objs(S['units']).where((x) => x['id'] == p['u']).firstOrNull;
        if (u == null) continue;
        final sub = c.split('.')[1]; final l = (u[sub] as List?) ?? (u[sub] = <dynamic>[]);
        final k = n0(p['k']).toInt(); l.insert(k.clamp(0, l.length), o);
      } else {
        final l = (S[c] as List?) ?? (S[c] = <dynamic>[]);
        if (o is Map && o['id'] != null && objs(l).any((x) => x['id'] == o['id'])) continue;
        final i = n0(p['i']).toInt(); l.insert(i.clamp(0, l.length), o);
      }
    }
    (S['trash'] as List).remove(r);
    await Store.I.save(log: '↩ رجّعت من السلة: ${str(r['l'])}');
    if (mounted) { setState(() {}); toast(context, L.t('↩ رجع')); }
  }
}
