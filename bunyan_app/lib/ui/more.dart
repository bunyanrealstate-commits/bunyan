import 'package:flutter/material.dart';
import 'hadith.dart';
import '../core/hq.dart';
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
import '../core/updater.dart';
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
        title: Text(st.linked ? Tr.t('متزامن مع حسابك') : Tr.t('مش مربوط')),
        subtitle: Text('${st.cfg['repo'] ?? ''}\n${st.syncMsg}'),
        isThreeLine: true,
      )),
      Card(child: ListTile(leading: const Text('🤖', style: TextStyle(fontSize: 18)), title: Text(Tr.t('اسأل بنيان (المساعد)')), subtitle: Text(Tr.t('Gemini المجاني — بيجاوب من أرقامك')), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiPage())))),
      Card(child: ListTile(leading: const Text('📒', style: TextStyle(fontSize: 18)), title: Text(Tr.t('الحسابات')), subtitle: Text(Tr.t('الرصيد، التأمينات، قفل الشهور، الدفتر')), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountsPage())))),
      Card(child: ListTile(leading: const Text('📑', style: TextStyle(fontSize: 18)), title: Text(Tr.t('الشيكات اللي معايا')), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChequesPage())))),
      Card(child: ListTile(leading: const Text('⏰', style: TextStyle(fontSize: 18)), title: Text(Tr.t('تذكيراتي')), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RemindersPage())))),
      Card(child: ListTile(leading: const Text('📂', style: TextStyle(fontSize: 18)), title: Text(Tr.t('المجموعات والشراكة')), subtitle: Text(Tr.t('فلوس الشراكة، الشركاء، طريقة الحساب')), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GroupsPage())))),
      Card(child: ListTile(leading: const Text('🔮', style: TextStyle(fontSize: 18)), title: Text(Tr.t('التوقعات — الرصيد سنة قدام')), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForecastPage())))),
      Card(child: ListTile(leading: const Text('📢', style: TextStyle(fontSize: 18)), title: Text(Tr.t('الأبديت (صورة الإعلان)')), subtitle: Text(Tr.t('نفس قايمة القديم — بتتزامن معاه')), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UpdPage())))),
      Card(child: ListTile(leading: const Text('📝', style: TextStyle(fontSize: 18)), title: Text(Tr.t('عقد العميل (PDF)')), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContractPage())))),
      Card(child: ListTile(leading: const Text('🧮', style: TextStyle(fontSize: 18)), title: Text(Tr.t('المحاكي — أفتح استديو جديد؟')), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SimPage())))),
      Card(child: ListTile(leading: const Text('📖', style: TextStyle(fontSize: 18)), title: Text(Tr.t('حديث أو قول دلوقتي')), subtitle: Text(Tr.t('بيظهر لوحده مرة كل ساعة')), trailing: const Icon(Icons.chevron_left), onTap: () => HQ.maybeShow(force: true))),
      Card(child: ListTile(leading: const Text('📜', style: TextStyle(fontSize: 18)), title: Text(Tr.t('طبقات الصوفية')), subtitle: Text(Tr.t('للسلمي — تراجمهم وأقوالهم وأخبارهم')), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SalafPage())))),
      Card(child: ListTile(leading: const Text('🛡', style: TextStyle(fontSize: 18)), title: Text(Tr.t('المراقب والشكاوى')), subtitle: Text(Tr.t('فحص البيانات + «مش عاجبني»')), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MonitorPage())))),
      Card(child: ListTile(leading: const Text('🗑', style: TextStyle(fontSize: 18)), title: Text(Tr.t('سلة المحذوفات')), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrashPage())))),
      Card(child: ListTile(leading: const Text('🔒', style: TextStyle(fontSize: 18)), title: Text(Tr.t('قفل التطبيق برقم سري')), subtitle: Text(AppLock.on ? Tr.t('مفعّل') : Tr.t('مش مفعّل')), trailing: const Icon(Icons.chevron_left), onTap: () => lockSettings(context))),
      Card(child: ListTile(leading: const Text('⬆️', style: TextStyle(fontSize: 18)), title: Text(Tr.t('تحديث التطبيق')), subtitle: Text('${Tr.t('النسخة')} ${Updater.mine}${Updater.latest > Updater.mine ? ' • ${Tr.t('فيه')} ${Updater.latest}' : ''}'), trailing: const Icon(Icons.chevron_left), onTap: () async { final m = await Updater.check(force: true); if (context.mounted) toast(context, m ?? (Updater.needPerm ? Tr.t('وافق على «السماح من هذا المصدر» من الشريط اللي فوق') : Tr.t('⏳ بيتحقق…'))); })),
      Card(child: ListTile(leading: const Text('🌐', style: TextStyle(fontSize: 18)), title: Text(Tr.t('اللغة / Language')), trailing: SegmentedButton<String>(segments: [ButtonSegment(value: 'ar', label: Text(Tr.t('عربي'))), ButtonSegment(value: 'en', label: Text('EN'))], selected: {Tr.lang}, onSelectionChanged: (x) => Tr.set(x.first)))),
      const SizedBox(height: 8),
      Text(Tr.t('🕘 سجل النشاط'), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      for (final e in h) Card(child: ListTile(
        dense: true,
        title: Text(str(e['d']).split('\n').first, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text('${str(e['by'])} • ${DateTime.fromMillisecondsSinceEpoch(n0(e['t']).toInt())}'.split('.').first),
        trailing: st.canUndo(e) ? TextButton(child: Text(Tr.t('↩ تراجع')), onPressed: () async {
          if (await confirmDlg(context, 'تلغي التعديل ده؟\n${str(e['d']).split('\n').first}', ok: Tr.t('ألغيه'))) { await st.undo(e); if (context.mounted) toast(context, Tr.t('↩ اتلغى التعديل')); }
        }) : null,
      )),
    ]);
  }
}
