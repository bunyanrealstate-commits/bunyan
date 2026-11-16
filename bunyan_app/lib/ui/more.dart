import 'package:flutter/material.dart';
import '../core/store.dart';
import '../core/js.dart';
import 'theme.dart';
import 'forecast.dart';
import 'groups.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});
  @override
  Widget build(BuildContext context) {
    final st = Store.I;
    final h = objs(st.S['hist']).take(60).toList();
    return ListView(padding: const EdgeInsets.all(14), children: [
      Card(child: ListTile(
        leading: const Icon(Icons.cloud_done, color: kGreen),
        title: Text(st.linked ? 'متزامن مع حسابك' : 'مش مربوط'),
        subtitle: Text('${st.cfg['repo'] ?? ''}\n${st.syncMsg}'),
        isThreeLine: true,
      )),
      Card(child: ListTile(leading: const Text('📂', style: TextStyle(fontSize: 22)), title: const Text('المجموعات والشراكة'), subtitle: const Text('فلوس الشراكة، الشركاء، طريقة الحساب'), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GroupsPage())))),
      Card(child: ListTile(leading: const Text('🔮', style: TextStyle(fontSize: 22)), title: const Text('التوقعات — الرصيد سنة قدام'), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForecastPage())))),
      const SizedBox(height: 8),
      const Text('🕘 سجل النشاط', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      for (final e in h) Card(child: ListTile(
        dense: true,
        title: Text(str(e['d']).split('\n').first, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text('${str(e['by'])} • ${DateTime.fromMillisecondsSinceEpoch(n0(e['t']).toInt())}'.split('.').first),
      )),
    ]);
  }
}
