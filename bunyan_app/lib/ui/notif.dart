/// 🔔 صفحة التنبيهات — نفس notifTab في بنيان القديم:
/// تنبيه شامل لكل العملاء • أرقام (متأخر/اليوم/الأسبوع/35 يوم) • متأخر / اليوم / غداً / خلال الأسبوع / خلال 35 يوم
/// كل إيجار جنبه 💬 واتساب (تذكير جاهز للمستأجر) و ✅ دفع
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'i18n.dart';
import '../core/store.dart';
import '../core/engine.dart';
import '../core/js.dart';
import '../core/actions.dart';
import '../core/native.dart';
import 'theme.dart';
import 'shell.dart';
import 'dialogs.dart';
import 'reminders.dart';

const _nty = {'rent': 'إيجار', 'inst': 'قسط الشركة', 'debt': 'دفعة مستحقة عليّ', 'recv': 'مستحقات لي', 'exp': 'مصروف', 'end': 'انتهاء عقد', 'cend': 'انتهاء عقد الشركة', 'rn': 'تجديد عقد', 'grace': 'أيام السماح'};
const _nin = ['rent', 'recv'];
const _days = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
const _mons = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
String dfmtL(String d) { final x = pd(d); return '${_days[x.weekday - 1]}، ${x.day} ${_mons[x.month - 1]} ${x.year}'; }

/// كل المواعيد مع n = عدد الأيام لحد الميعاد
List<Map<String, dynamic>> notifItems(Engine e) => e.items().map((x) => {...x, 'n': Engine.dd(x['d'])}).toList()..sort((a, b) => str(a['d']).compareTo(str(b['d'])));
bool _money(Map x) => n0(x['amt']) != 0 && _nty.containsKey(x['ty']) && x['ty'] != 'end' && x['ty'] != 'cend';
/// تنبيهات النهارده (نفس alertsNow: الميعاد بعد عدد أيام من offs بالظبط)
List<Map<String, dynamic>> alertsNow(Engine e) => notifItems(e).where((x) => lst(x['offs']).map((o) => n(o).toInt()).contains(x['n'] as int)).toList()..sort((a, b) => (a['n'] as int).compareTo(b['n'] as int));
int overdueN(Engine e) => notifItems(e).where((x) => (x['n'] as int) < 0 && ['rent', 'inst', 'debt'].contains(x['ty'])).length;

/// نفس whenTxt في القديم
String whenTxt(int n) => n < 0 ? 'متأخر ${-n} يوم' : const {0: 'اليوم', 1: 'غداً', 2: 'بعد يومين', 7: 'بعد أسبوع', 14: 'بعد أسبوعين', 21: 'بعد 3 أسابيع', 30: 'بعد شهر'}[n] ?? 'بعد $n يوم';

/// شارة الأيام (زي badge في القديم)
Widget dayBadge(int n) {
  final c = n < 0 ? kRed : n <= 7 ? kTerra : n <= 30 ? const Color(0xFFD97706) : kGreen;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(99)),
    child: Text(n < 0 ? 'متأخرة ${-n} يوم' : n == 0 ? 'اليوم' : n == 1 ? 'غداً' : 'بعد $n يوم', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
  );
}

/* ───────── واتساب: تذكير جاهز للمستأجر (نفس msg/dg في القديم) ───────── */
String _dg(dynamic p) {
  var d = str(p).replaceAllMapped(RegExp('[٠-٩]'), (m) => '${'٠١٢٣٤٥٦٧٨٩'.indexOf(m[0]!)}').replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('00')) d = d.substring(2);
  if (RegExp(r'^01\d{9}$').hasMatch(d)) { d = '2$d'; } else if (RegExp(r'^05\d{8}$').hasMatch(d)) { d = '971${d.substring(1)}'; }
  return d;
}

Future<void> sendWa(BuildContext context, Map<String, dynamic> x) async {
  final u = Act.unit(str(x['u'])); if (u == null) return;
  final k = x['k'] as int, i = x['i'] as int; final L = objs(u['leases'])[k]; final n = x['n'] as int;
  final ph = _dg(L['phone']);
  final wab = str(Store.I.S['wab']);
  final t = 'السلام عليكم ${str(L['tenant'])}،\nتذكير بإيجار ${str(u['name'])} (${truthy(L['sch']) ? 'الدفعة ' : 'شهر '}${i + 1}) بمبلغ ${money(Engine.la(L, i))}${n < 0 ? ' — متأخر ${-n} يوم' : ''}.\nتاريخ الاستحقاق: ${x['d']}.\nشكراً لك.${wab.isEmpty ? '' : '\nللتواصل: $wab'}';
  if (ph.isEmpty) { toast(context, Tr.t('مفيش رقم واتساب للمستأجر — ضيفه من تعديل العقد')); return; }
  final ok = await Native.openUrl('https://wa.me/$ph?text=${Uri.encodeComponent(t)}');
  if (!ok) await Share.share(t);
}

Future<void> payRent(BuildContext context, Map<String, dynamic> x) async {
  final u = Act.unit(str(x['u'])); if (u == null) return;
  final k = x['k'] as int, i = x['i'] as int; final L = objs(u['leases'])[k];
  if (Engine.rcv(L).contains(i)) { toast(context, Tr.t('الشهر ده متسجل مستلم بالفعل')); return; }
  if (!await lockOk(context, [str(x['d'])]) || !context.mounted) return;
  if (await confirmDlg(context, 'تأكيد استلام ${money(Engine.la(L, i))} من ${str(L['tenant'])} — ${str(u['name'])} (دفعة ${i + 1})؟')) {
    await Act.rentPaid(u, k, i);
    if (context.mounted) toast(context, '✅ اتسجل: استلمت ${money(Engine.la(L, i))} من ${str(L['tenant'])}');
  }
}

Widget _waBtn(BuildContext context, Map<String, dynamic> x) {
  final u = Act.unit(str(x['u'])); final L = u == null ? null : objs(u['leases'])[x['k'] as int];
  final has = L != null && _dg(L['phone']).isNotEmpty;
  return InkWell(
    borderRadius: BorderRadius.circular(10), onTap: () => sendWa(context, x),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: const Color(0x1A1F9D55), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1F9D55), width: 1.4, style: has ? BorderStyle.solid : BorderStyle.solid)),
      child: Text(has ? '💬 واتساب' : '➕ رقم واتساب', style: const TextStyle(color: Color(0xFF14783F), fontWeight: FontWeight.w800, fontSize: 12.5)),
    ),
  );
}

Widget _payBtn(BuildContext context, Map<String, dynamic> x) => InkWell(
      borderRadius: BorderRadius.circular(10), onTap: () => payRent(context, x),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: kOk, borderRadius: BorderRadius.circular(10)), child: const Text('✅ دفع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5))),
    );

/// سطر موعد (زي row في notifTab)
Widget notifRow(BuildContext context, Map<String, dynamic> x, {bool bell = false}) {
  final ty = str(x['ty']); final n = x['n'] as int; final a = n0(x['amt']);
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE6E8EE)))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (bell) const Text('🔔'),
            if (_nty[ty] != null) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: _tagC(ty).withOpacity(.12), borderRadius: BorderRadius.circular(99)), child: Text(_nty[ty]!, style: TextStyle(color: _tagC(ty), fontSize: 11.5, fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 3),
          Text(Priv.txt(str(x['label'])), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: kNavy)),
          Text(dfmtL(str(x['d'])), style: const TextStyle(color: kMuted, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          dayBadge(n),
          if (a != 0) Padding(padding: const EdgeInsets.only(top: 6), child: ptxt(moneyRaw(a), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5, color: _nin.contains(ty) ? kGreen : kRed))),
        ]),
      ]),
      if (ty == 'rent') Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [_waBtn(context, x), const SizedBox(width: 8), _payBtn(context, x)])),
    ]),
  );
}
Color _tagC(String ty) => switch (ty) { 'rent' => kGreen, 'inst' => kRed, 'end' || 'cend' => kMuted, 'rn' => kTerra, _ => kAc };

/* ───────── «تنبيه شامل لكل العملاء»: كل الإيجارات المتأخرة أو المستحقة خلال 7 أيام ───────── */
List<Map<String, dynamic>> _alxRows(Engine e) => notifItems(e).where((x) => x['ty'] == 'rent' && (x['n'] as int) <= 7).toList()..sort((a, b) => (a['n'] as int).compareTo(b['n'] as int));

void openAlx(BuildContext context) {
  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => Directionality(textDirection: Tr.dir, child: DraggableScrollableSheet(expand: false, initialChildSize: .8, maxChildSize: .95, builder: (_, sc) {
      final r = _alxRows(Engine(Store.I.S, WS: Ws.I.resolve())); final sum = r.fold(0.0, (s, x) => s + n0(x['amt']));
      return ListView(controller: sc, padding: const EdgeInsets.fromLTRB(16, 14, 16, 30), children: [
        Row(children: [const Expanded(child: Text('🔔 كل العملاء — متأخر وقريب', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18))), IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close))]),
        Text('الإجمالي: ${money(sum)} • ${r.length} عميل', style: const TextStyle(color: kMuted, fontWeight: FontWeight.w700)),
        if (r.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('لا يوجد عملاء متأخرين أو قريبي الاستحقاق ✅', style: TextStyle(color: kMuted))),
        for (final x in r) notifRow(ctx, x),
      ]);
    })));
}

class NotifPage extends StatelessWidget {
  const NotifPage({super.key});
  @override
  Widget build(BuildContext context) => Directionality(textDirection: Tr.dir, child: Scaffold(
        appBar: AppBar(title: Text(Tr.t('🔔 التنبيهات'))),
        body: ListenableBuilder(listenable: Listenable.merge([Store.I, Ws.I]), builder: (ctx, __) {
          final e = Engine(Store.I.S, WS: Ws.I.resolve());
          final all = notifItems(e); final al = alertsNow(e); final ak = al.map((x) => '${x['id']}|${x['d']}').toSet();
          List<Map<String, dynamic>> w(bool Function(int n) f) => all.where((x) => f(x['n'] as int)).toList();
          final od = all.where((x) => (x['n'] as int) < 0 && _money(x)).toList();
          final G = <List<dynamic>>[['🔴 متأخر', od, kRed], ['اليوم', w((n) => n == 0), kAc], ['غداً', w((n) => n == 1), kAc], ['خلال الأسبوع', w((n) => n >= 2 && n <= 7), const Color(0xFF7C3AED)], ['خلال 35 يوم', w((n) => n >= 8 && n <= 35), kTerra]];
          ({double i, double o}) tot(List<Map<String, dynamic>> l) => (i: l.where((x) => _nin.contains(x['ty'])).fold(0.0, (s, x) => s + n0(x['amt'])), o: l.where((x) => !_nin.contains(x['ty'])).fold(0.0, (s, x) => s + n0(x['amt'])));
          Widget sm(String t, List<Map<String, dynamic>> l, Color c) {
            final a = tot(l);
            return Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Color.alphaBlend(c.withOpacity(.07), Colors.white), border: Border(right: BorderSide(color: c, width: 5))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: const TextStyle(color: kMuted, fontWeight: FontWeight.w700, fontSize: 13)),
                Text('${l.length}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: l.isNotEmpty && t == 'متأخر' ? kRed : kInk)),
                if (a.i != 0) Text.rich(TextSpan(children: [const TextSpan(text: 'ستستلم '), TextSpan(text: money(a.i), style: const TextStyle(color: kGreen, fontWeight: FontWeight.w900))]), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                if (a.o != 0) Text.rich(TextSpan(children: [const TextSpan(text: 'ستدفع '), TextSpan(text: money(a.o), style: const TextStyle(color: kRed, fontWeight: FontWeight.w900))]), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                if (a.i == 0 && a.o == 0) const Text('—', style: TextStyle(color: kMuted)),
              ]),
            );
          }
          final alx = _alxRows(e); final aod = alx.where((x) => (x['n'] as int) < 0).toList(), asn = alx.where((x) => (x['n'] as int) >= 0).toList();
          double s(List<Map<String, dynamic>> l) => l.fold(0.0, (q, x) => q + n0(x['amt']));
          return ListView(padding: const EdgeInsets.fromLTRB(10, 10, 14, 40), children: [
            if (alx.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: InkWell(
              borderRadius: BorderRadius.circular(18), onTap: () => openAlx(ctx),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: const Color(0x12E5484D), border: Border.all(color: const Color(0xFFE5484D), width: 1.5)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('🔔 تنبيه شامل لكل العملاء', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kAc)),
                  const SizedBox(height: 6),
                  Text('${aod.isNotEmpty ? '🔴 ${aod.length} متأخر (${money(s(aod))})  ' : ''}${asn.isNotEmpty ? '🟠 ${asn.length} مستحق خلال 7 أيام (${money(s(asn))})' : ''}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  const Text('اضغط لعرض الكل وإرسال تذكير لكل عميل', style: TextStyle(color: kMuted, fontSize: 12.5)),
                ]),
              ),
            )),
            GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.35, children: [
              sm('متأخر', od, kOk), sm('اليوم', all.where((x) => x['n'] == 0 && _money(x)).toList(), kAc),
              sm('خلال الأسبوع', all.where((x) => (x['n'] as int) >= 0 && (x['n'] as int) <= 7 && _money(x)).toList(), kTerra),
              sm('خلال 35 يوم', all.where((x) => (x['n'] as int) >= 0 && (x['n'] as int) <= 35 && _money(x)).toList(), const Color(0xFF7C3AED)),
            ]),
            const SizedBox(height: 12),
            for (final g in G) if ((g[1] as List).isNotEmpty) BCard(c: g[2] as Color, title: '${g[0]} (${(g[1] as List).length})', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final x in (g[1] as List<Map<String, dynamic>>).take(80)) notifRow(ctx, x, bell: ak.contains('${x['id']}|${x['d']}')),
            ])),
            if (od.isEmpty && all.where((x) => (x['n'] as int) >= 0 && (x['n'] as int) <= 35).isEmpty)
              BCard(c: kOk, child: const Text('لا توجد مواعيد قادمة ولا متأخرات. كل شيء على ما يرام ✅', style: TextStyle(color: kMuted))),
            BCard(c: kTeal, title: Tr.t('إعدادات التنبيهات'), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('الإيجارات: قبلها بيوم وفي يوم الاستحقاق. دفعات الشركة: قبلها بشهر، 3 أسابيع، أسبوعين، أسبوع، يومين، ويوم الموعد. بقية المواعيد (مصاريف، انتهاء العقود): يوم الاستحقاق.', style: TextStyle(color: kMuted, height: 1.6)),
              const SizedBox(height: 6),
              const Text('📲 التطبيق بيبعتلك إشعار على الموبايل في نفس المواعيد دي حتى لو مقفول.', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: () => Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const RemindersPage())), child: Text(Tr.t('⏰ تذكيراتي الخاصة'))),
              const SizedBox(height: 6),
              OutlinedButton(onPressed: () => _wab(ctx), child: Text(str(Store.I.S['wab']).isEmpty ? Tr.t('📞 رقم واتساب الأعمال (بيظهر في رسائل التذكير)') : '📞 رقمي في الرسائل: ${str(Store.I.S['wab'])}')),
            ])),
          ]);
        }),
      ));

  Future<void> _wab(BuildContext context) async {
    final o = await formDlg(context, Tr.t('رقم واتساب الأعمال الخاص بي'), [FieldSpec('w', Tr.t('الرقم مع كود الدولة (مثال 971501234567)'), v: str(Store.I.S['wab']))]);
    if (o == null) return;
    Store.I.S['wab'] = _dg(o['w']); await Store.I.save(log: '📞 رقم واتساب الأعمال');
    if (context.mounted) toast(context, Tr.t('تم الحفظ'));
  }
}

/* ───────── الشريط الملوّن فوق الداشبورد (ntb): عدد التنبيهات والمتأخر + أول تنبيهين ───────── */
class NtBar extends StatelessWidget {
  final Engine e;
  const NtBar(this.e, {super.key});
  @override
  Widget build(BuildContext context) {
    final al = alertsNow(e); final od = overdueN(e);
    if (al.isEmpty && od == 0) return const SizedBox.shrink();
    Widget pill(String t) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: Colors.white.withOpacity(.22), borderRadius: BorderRadius.circular(99)), child: Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)));
    return InkWell(
      borderRadius: BorderRadius.circular(16), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotifPage())),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(color: od > 0 ? const Color(0xFFE5393F) : kAc, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: (od > 0 ? kRed : kAc).withOpacity(.35), blurRadius: 14, offset: const Offset(0, 6))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 6, runSpacing: 4, children: [
            const Text('🔔', style: TextStyle(fontSize: 15)),
            if (al.isNotEmpty) pill('${al.length} ${al.length > 2 ? 'تنبيهات' : al.length == 2 ? 'تنبيهين' : 'تنبيه'}'),
            if (od > 0) pill('🔴 $od متأخر'),
          ]),
          for (final a in al.take(2)) Padding(padding: const EdgeInsets.only(top: 6), child: Text.rich(TextSpan(children: [TextSpan(text: '${whenTxt(a['n'] as int)}: ', style: const TextStyle(fontWeight: FontWeight.w900)), TextSpan(text: Priv.txt(str(a['label'])))]), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14, height: 1.4))),
          if (al.length > 2) Padding(padding: const EdgeInsets.only(top: 4), child: Text('+${al.length - 2} أخرى', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
        ]),
      ),
    );
  }
}
