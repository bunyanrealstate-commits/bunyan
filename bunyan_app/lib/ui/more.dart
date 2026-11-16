import 'package:flutter/material.dart';
import '../core/store.dart';
import '../core/js.dart';
import 'theme.dart';
import 'forecast.dart';
import 'groups.dart';
import 'reminders.dart';
import 'trash.dart';
import 'accounts.dart';
import 'dialogs.dart';
import 'cheques.dart';
import 'lock.dart';
import 'sim.dart';
import 'contract.dart';
import 'ai.dart';

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
      Card(child: ListTile(leading: const Text('🤖', style: TextStyle(fontSize: 22)), title: const Text('اسأل بنيان (المساعد)'), subtitle: const Text('Gemini المجاني — بيجاوب من أرقامك'), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiPage())))),
      Card(child: ListTile(leading: const Text('📒', style: TextStyle(fontSize: 22)), title: const Text('الحسابات'), subtitle: const Text('الرصيد، التأمينات، قفل الشهور، الدفتر'), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountsPage())))),
      Card(child: ListTile(leading: const Text('📑', style: TextStyle(fontSize: 22)), title: const Text('الشيكات اللي معايا'), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChequesPage())))),
      Card(child: ListTile(leading: const Text('⏰', style: TextStyle(fontSize: 22)), title: const Text('تذكيراتي'), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RemindersPage())))),
      Card(child: ListTile(leading: const Text('📂', style: TextStyle(fontSize: 22)), title: const Text('المجموعات والشراكة'), subtitle: const Text('فلوس الشراكة، الشركاء، طريقة الحساب'), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GroupsPage())))),
      Card(child: ListTile(leading: const Text('🔮', style: TextStyle(fontSize: 22)), title: const Text('التوقعات — الرصيد سنة قدام'), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForecastPage())))),
      Card(child: ListTile(leading: const Text('📝', style: TextStyle(fontSize: 22)), title: const Text('عقد العميل (PDF)'), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContractPage())))),
      Card(child: ListTile(leading: const Text('🧮', style: TextStyle(fontSize: 22)), title: const Text('المحاكي — أفتح استديو جديد؟'), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SimPage())))),
      Card(child: ListTile(leading: const Text('🗑', style: TextStyle(fontSize: 22)), title: const Text('سلة المحذوفات'), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrashPage())))),
      Card(child: ListTile(leading: const Text('🔒', style: TextStyle(fontSize: 22)), title: const Text('قفل التطبيق برقم سري'), subtitle: Text(AppLock.on ? 'مفعّل' : 'مش مفعّل'), trailing: const Icon(Icons.chevron_left), onTap: () => lockSettings(context))),
      const SizedBox(height: 8),
      const Text('🕘 سجل النشاط', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      for (final e in h) Card(child: ListTile(
        dense: true,
        title: Text(str(e['d']).split('\n').first, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text('${str(e['by'])} • ${DateTime.fromMillisecondsSinceEpoch(n0(e['t']).toInt())}'.split('.').first),
        trailing: st.canUndo(e) ? TextButton(child: const Text('↩ تراجع'), onPressed: () async {
          if (await confirmDlg(context, 'تلغي التعديل ده؟\n${str(e['d']).split('\n').first}', ok: 'ألغيه')) { await st.undo(e); if (context.mounted) toast(context, '↩ اتلغى التعديل'); }
        }) : null,
      )),
    ]);
  }
}
