import 'package:flutter/material.dart';
import 'i18n.dart';
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
import 'monitor.dart';
import 'upd.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});
  @override
  Widget build(BuildContext context) {
    final st = Store.I;
    final h = objs(st.S['hist']).take(60).toList();
    return ListView(padding: const EdgeInsets.all(14), children: [
      Card(child: ListTile(
        leading: const Icon(Icons.cloud_done, color: kGreen),
        title: Text(st.linked ? L.t('متزامن مع حسابك') : L.t('مش مربوط')),
        subtitle: Text('${st.cfg['repo'] ?? ''}\n${st.syncMsg}'),
        isThreeLine: true,
      )),
      Card(child: ListTile(leading: const Text('🤖', style: TextStyle(fontSize: 22)), title: Text(L.t('اسأل بنيان (المساعد)')), subtitle: Text(L.t('Gemini المجاني — بيجاوب من أرقامك')), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiPage())))),
      Card(child: ListTile(leading: const Text('📒', style: TextStyle(fontSize: 22)), title: Text(L.t('الحسابات')), subtitle: Text(L.t('الرصيد، التأمينات، قفل الشهور، الدفتر')), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountsPage())))),
      Card(child: ListTile(leading: const Text('📑', style: TextStyle(fontSize: 22)), title: Text(L.t('الشيكات اللي معايا')), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChequesPage())))),
      Card(child: ListTile(leading: const Text('⏰', style: TextStyle(fontSize: 22)), title: Text(L.t('تذكيراتي')), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RemindersPage())))),
      Card(child: ListTile(leading: const Text('📂', style: TextStyle(fontSize: 22)), title: Text(L.t('المجموعات والشراكة')), subtitle: Text(L.t('فلوس الشراكة، الشركاء، طريقة الحساب')), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GroupsPage())))),
      Card(child: ListTile(leading: const Text('🔮', style: TextStyle(fontSize: 22)), title: Text(L.t('التوقعات — الرصيد سنة قدام')), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForecastPage())))),
      Card(child: ListTile(leading: const Text('📢', style: TextStyle(fontSize: 22)), title: Text(L.t('الأبديت (صورة الإعلان)')), subtitle: Text(L.t('نفس قايمة القديم — بتتزامن معاه')), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UpdPage())))),
      Card(child: ListTile(leading: const Text('📝', style: TextStyle(fontSize: 22)), title: Text(L.t('عقد العميل (PDF)')), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContractPage())))),
      Card(child: ListTile(leading: const Text('🧮', style: TextStyle(fontSize: 22)), title: Text(L.t('المحاكي — أفتح استديو جديد؟')), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SimPage())))),
      Card(child: ListTile(leading: const Text('🛡', style: TextStyle(fontSize: 22)), title: Text(L.t('المراقب والشكاوى')), subtitle: Text(L.t('فحص البيانات + «مش عاجبني»')), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MonitorPage())))),
      Card(child: ListTile(leading: const Text('🗑', style: TextStyle(fontSize: 22)), title: Text(L.t('سلة المحذوفات')), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrashPage())))),
      Card(child: ListTile(leading: const Text('🔒', style: TextStyle(fontSize: 22)), title: Text(L.t('قفل التطبيق برقم سري')), subtitle: Text(AppLock.on ? L.t('مفعّل') : L.t('مش مفعّل')), trailing: const Icon(Icons.chevron_left), onTap: () => lockSettings(context))),
      Card(child: ListTile(leading: const Text('🌐', style: TextStyle(fontSize: 22)), title: const Text('اللغة / Language'), trailing: SegmentedButton<String>(segments: const [ButtonSegment(value: 'ar', label: Text('عربي')), ButtonSegment(value: 'en', label: Text('EN'))], selected: {L.lang}, onSelectionChanged: (x) => L.set(x.first)))),
      const SizedBox(height: 8),
      Text(L.t('🕘 سجل النشاط'), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      for (final e in h) Card(child: ListTile(
        dense: true,
        title: Text(str(e['d']).split('\n').first, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text('${str(e['by'])} • ${DateTime.fromMillisecondsSinceEpoch(n0(e['t']).toInt())}'.split('.').first),
        trailing: st.canUndo(e) ? TextButton(child: Text(L.t('↩ تراجع')), onPressed: () async {
          if (await confirmDlg(context, 'تلغي التعديل ده؟\n${str(e['d']).split('\n').first}', ok: L.t('ألغيه'))) { await st.undo(e); if (context.mounted) toast(context, L.t('↩ اتلغى التعديل')); }
        }) : null,
      )),
    ]);
  }
}
