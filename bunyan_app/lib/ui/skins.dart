import 'package:flutter/material.dart';
import '../core/engine.dart';
import '../core/actions.dart';
import 'dialogs.dart';
import '../core/js.dart';
import '../core/store.dart';
import 'ai.dart';
import 'dash.dart';
import 'i18n.dart';
import 'shell.dart';
import 'theme.dart';
import 'units.dart';
import 'lease_edit.dart';

/// 🎨 أشكال البرنامج — تجرّبهم كلهم وتختار اللي ترتاحله (المزيد ← شكل البرنامج)
class Skin {
  static const all = [
    ['classic', '🏠 الحالي', 'تبويبات فوق وصورة المدينة'],
    ['fb', '📘 زي فيسبوك', 'فاتح، شريط تحت، المجموعات دواير'],
    ['ps', '🌙 داكن فخم', 'زي فوتوشوب: داكن وزرار ➕ في النص'],
    ['bank', '🏦 زي البنوك', 'الرصيد في هيدر كحلي وآخر الحركات'],
    ['bnb', '🏡 زي Airbnb', 'كل استديو كارت كبير وبحث فوق'],
    ['wallet', '💳 زي محفظة آيفون', 'كل مجموعة كارت ملوّن فوق بعض'],
  ];
  static String get id { final v = str(Store.I.cfg['skin']); return all.any((s) => s[0] == v) ? v : 'classic'; }
  static bool get classic => id == 'classic';
  static bool get dark => id == 'ps';
  static Future<void> set(String v) async { Store.I.cfg['skin'] = v; await Store.I.saveCfg(); Store.I.notifyListeners(); }
  static Color get bg => switch (id) { 'ps' => const Color(0xFF0B1220), 'fb' => const Color(0xFFF0F2F5), 'wallet' => const Color(0xFFF2F2F7), 'bnb' => Colors.white, _ => kBg };
  static Color get bar => switch (id) { 'ps' => const Color(0xFF0B1220), 'bank' => const Color(0xFF1E3A8A), _ => Colors.white };
  static Color get barFg => (id == 'ps' || id == 'bank') ? Colors.white : kNavy;
  static Color get acc => switch (id) { 'ps' => const Color(0xFF14B8A6), 'bank' => const Color(0xFF1E3A8A), 'fb' => const Color(0xFF0F766E), 'bnb' => const Color(0xFFE11D48), _ => kAc };
}

/// اختيار الشكل
Future<void> skinPicker(BuildContext context) => showModalBottomSheet(context: context, isScrollControlled: true, builder: (ctx) => Directionality(textDirection: Tr.dir, child: SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('🎨 شكل البرنامج', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        const Text('جرّب أي شكل — بيتغيّر على طول، وترجع تغيّره في أي وقت. أرقامك ما بتتأثرش.', style: TextStyle(color: kMuted, fontSize: 12.5)),
        const SizedBox(height: 10),
        for (final s in Skin.all) Padding(padding: const EdgeInsets.only(bottom: 6), child: InkWell(
          borderRadius: BorderRadius.circular(14), onTap: () async { Navigator.pop(ctx); Shell.go(0); await Skin.set(s[0]); },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: Skin.id == s[0] ? const Color(0xFFE6F4F1) : Colors.white, border: Border.all(color: Skin.id == s[0] ? kAc : kBd)),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s[1], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)), Text(s[2], style: const TextStyle(color: kMuted, fontSize: 12))])),
              if (Skin.id == s[0]) const Icon(Icons.check_circle, color: kAc),
            ]),
          ),
        )),
      ]),
    ))));

/* ───────── الشريط اللي تحت ───────── */
class SkinNav extends StatelessWidget {
  final int tab; final ValueChanged<int> go;
  const SkinNav(this.tab, this.go, {super.key});
  static const items = [[0, Icons.home_rounded, 'الرئيسية'], [1, Icons.apartment_rounded, 'الاستديوهات'], [2, Icons.bar_chart_rounded, 'الحسابات'], [3, Icons.receipt_long_rounded, 'المصاريف'], [5, Icons.menu_rounded, 'المزيد']];
  @override
  Widget build(BuildContext context) {
    final ps = Skin.dark, a = Skin.acc;
    Widget it(List x) {
      final on = tab == x[0];
      return Expanded(child: InkWell(onTap: () => go(x[0] as int), child: Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3), decoration: BoxDecoration(color: on && Skin.id != 'bnb' ? a.withOpacity(ps ? .22 : .12) : Colors.transparent, borderRadius: BorderRadius.circular(99)),
          child: Icon(x[1] as IconData, size: 23, color: on ? (ps ? const Color(0xFF5EEAD4) : a) : (ps ? const Color(0xFF64748B) : const Color(0xFF8A94A6)))),
        const SizedBox(height: 2),
        Text(Tr.t(x[2] as String), style: TextStyle(fontSize: 10.5, fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: on ? (ps ? Colors.white : a) : (ps ? const Color(0xFF64748B) : const Color(0xFF8A94A6)))),
      ]))));
    }
    final kids = <Widget>[for (final x in items.take(2)) it(x), if (ps) Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: InkWell(customBorder: const CircleBorder(), onTap: () => quickAdd(context), child: Container(width: 48, height: 48, decoration: const BoxDecoration(color: Color(0xFF14B8A6), shape: BoxShape.circle), child: const Icon(Icons.add, color: Color(0xFF042F2E), size: 28)))), for (final x in items.skip(2)) it(x)];
    return Container(
      decoration: BoxDecoration(color: ps ? const Color(0xFF111C2E) : Colors.white, border: Border(top: BorderSide(color: ps ? const Color(0xFF1E293B) : kBd))),
      child: SafeArea(top: false, child: Row(children: kids)),
    );
  }
}

/// ➕ إضافة سريعة
void quickAdd(BuildContext context) => showModalBottomSheet(context: context, builder: (ctx) => Directionality(textDirection: Tr.dir, child: SafeArea(child: Padding(padding: const EdgeInsets.all(14), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('➕ أضيف إيه؟', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      const SizedBox(height: 8),
      for (final o in [[Icons.payments_outlined, 'استلام إيجار', 1], [Icons.receipt_long_outlined, 'مصروف', 3], [Icons.description_outlined, 'عقد عميل', 6], [Icons.smart_toy_outlined, 'قول لنموذج بنيان', -1]])
        ListTile(leading: Icon(o[0] as IconData, color: kAc), title: Text(o[1] as String, style: const TextStyle(fontWeight: FontWeight.w800)), onTap: () { Navigator.pop(ctx); final i = o[2] as int; if (i < 0) { Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiPage())); } else { Shell.go(i); } }),
    ])))));

String _m(num v) => Priv.on ? '•••' : v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/* ───────── أول الداشبورد حسب الشكل ───────── */
class SkinHero extends StatelessWidget {
  final Engine e;
  const SkinHero(this.e, {super.key});

  Widget _quick(BuildContext context, Color c, {Color fg = kNavy, Color? bg}) {
    final o = [[Icons.payments_outlined, 'إيجار', 1], [Icons.receipt_long_outlined, 'مصروف', 3], [Icons.description_outlined, 'عقد', 6], [Icons.smart_toy_outlined, 'اسأل', -1]];
    return Row(children: [
      for (final x in o) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () { final i = x[2] as int; if (i < 0) { Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiPage())); } else { Shell.go(i); } },
        child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: bg ?? Colors.white, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [Icon(x[0] as IconData, color: c, size: 23), const SizedBox(height: 3), Text(Tr.t(x[1] as String), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg))])),
      ))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final cash = e.cashNow(); final rp = e.rcvP(); final ev = e.events(); final p = ev.isEmpty ? null : e.project(ev);
    final wd = p == null ? 0.0 : p['min'] as double;
    final gs = objs(Store.I.S['groups']); final cur = Ws.I.resolve();
    switch (Skin.id) {
      case 'fb':
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(height: 86, child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final g in gs) GestureDetector(onTap: () => Ws.I.pick(str(g['id'])), child: Padding(padding: const EdgeInsetsDirectional.only(end: 12), child: Column(children: [
              Container(width: 56, height: 56, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: g['id'] == cur ? const Color(0xFFE6F4F1) : const Color(0xFFE4E6EB), border: Border.all(color: g['id'] == cur ? kAc : Colors.transparent, width: 2.5)),
                child: Text(Priv.on ? '•' : str(g['name']).replaceAll('مع ', '').characters.first, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: g['id'] == cur ? kAc : kNavy))),
              const SizedBox(height: 3),
              SizedBox(width: 66, child: Text(Priv.on ? '••' : str(g['name']), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
            ]))),
          ])),
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF0F766E), borderRadius: BorderRadius.circular(18)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('الرصيد النقدي', style: TextStyle(color: Color(0xFFCCFBF1), fontSize: 12.5)),
            Text('${_m(cash)} درهم', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('ربح ${_m(rp['profit']!)}', style: const TextStyle(color: Color(0xFFCCFBF1), fontSize: 12)), Text('تقدر تسحب ${_m(wd)}', style: const TextStyle(color: Color(0xFFCCFBF1), fontSize: 12))]),
          ])),
          const SizedBox(height: 10),
          _quick(context, const Color(0xFF0F766E)),
        ]);
      case 'ps':
        final bars = [.3, .45, .38, .6, .72, 1.0];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(height: 34, child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final g in gs) Padding(padding: const EdgeInsetsDirectional.only(end: 6), child: InkWell(borderRadius: BorderRadius.circular(99), onTap: () => Ws.I.pick(str(g['id'])), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14), alignment: Alignment.center, decoration: BoxDecoration(color: g['id'] == cur ? const Color(0xFF14B8A6) : const Color(0xFF1E293B), borderRadius: BorderRadius.circular(99)),
              child: Text(Priv.on ? '••' : str(g['name']), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: g['id'] == cur ? const Color(0xFF042F2E) : const Color(0xFFCBD5E1)))))),
          ])),
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF111C2E), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF1E3A4C))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('الرصيد النقدي', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5)),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(_m(cash), style: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 30, fontWeight: FontWeight.w900)), const SizedBox(width: 6), const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('AED', style: TextStyle(color: Color(0xFF5EEAD4), fontWeight: FontWeight.w800)))]),
            const SizedBox(height: 8),
            SizedBox(height: 40, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [for (var i = 0; i < bars.length; i++) Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 2), height: 40 * bars[i], decoration: BoxDecoration(color: Color.lerp(const Color(0xFF134E4A), const Color(0xFF14B8A6), i / 5), borderRadius: BorderRadius.circular(4))))])),
          ])),
          const SizedBox(height: 8),
          Row(children: [
            for (final x in [['ربح حتى اليوم', rp['profit']!, const Color(0xFF5EEAD4)], ['تقدر تسحب', wd, const Color(0xFFFBBF24)]]) Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 3), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF111C2E), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1E293B))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(x[0] as String, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)), Text(_m(x[1] as num), style: TextStyle(color: x[2] as Color, fontSize: 20, fontWeight: FontWeight.w900))]))),
          ]),
        ]);
      case 'bank':
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(padding: const EdgeInsets.fromLTRB(16, 16, 16, 44), decoration: BoxDecoration(color: const Color(0xFF1E3A8A), borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('الرصيد المتاح • ${Priv.on ? '••' : str(gs.where((g) => g['id'] == cur).firstOrNull?['name'])}', style: const TextStyle(color: Color(0xFFBFDBFE), fontSize: 12.5)),
            Text('AED ${_m(cash)}', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
            Text('ربح ${_m(rp['profit']!)} • تقدر تسحب ${_m(wd)}', style: const TextStyle(color: Color(0xFFBFDBFE), fontSize: 12)),
          ])),
          Transform.translate(offset: const Offset(0, -30), child: Container(margin: const EdgeInsets.symmetric(horizontal: 10), padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBd), boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 4))]), child: _quick(context, const Color(0xFF1E3A8A)))),
          Transform.translate(offset: const Offset(0, -18), child: BankMoves(e)),
        ]);
      case 'bnb':
        final us = e.SU();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InkWell(borderRadius: BorderRadius.circular(99), onTap: () => Shell.go(1), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99), border: Border.all(color: kBd), boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 3))]),
            child: const Row(children: [Icon(Icons.search, size: 20), SizedBox(width: 8), Text('دوّر على استديو أو مستأجر', style: TextStyle(color: kMuted))]))),
          const SizedBox(height: 12),
          Row(children: [Text('💵 ${_m(cash)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), const Spacer(), Text('ربح ${_m(rp['profit']!)} • سحب ${_m(wd)}', style: const TextStyle(color: kMuted, fontSize: 12))]),
          const SizedBox(height: 10),
          for (final u in us) _bnbCard(context, u),
        ]);
      case 'wallet':
        final cols = [const Color(0xFF0F766E), const Color(0xFF14304A), const Color(0xFFB7791F), const Color(0xFF4338CA), const Color(0xFF0369A1)];
        final order = [...gs.where((g) => g['id'] != cur), ...gs.where((g) => g['id'] == cur)];
        final n = order.length;
        return SizedBox(height: 46.0 * (n - 1) + 160, child: Stack(children: [
          for (var i = 0; i < n; i++) Positioned(top: 46.0 * i, left: 0, right: 0, child: GestureDetector(
            onTap: () => Ws.I.pick(str(order[i]['id'])),
            child: Container(height: i == n - 1 ? 160 : 120, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: cols[gs.indexOf(order[i]) % cols.length], borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 12, offset: Offset(0, -2))]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Text(Priv.on ? '••' : str(order[i]['name']), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)), const Spacer(), Text('${objs(Store.I.S['units']).where((u) => u['g'] == order[i]['id']).length} استديو', style: const TextStyle(color: Colors.white70, fontSize: 12))]),
                if (i == n - 1) ...[
                  const Spacer(),
                  const Text('الرصيد', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(_m(cash), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                  Text('ربح ${_m(rp['profit']!)} • سحب ${_m(wd)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ])),
          )),
        ]));
    }
    return const HeroScene();
  }

  Widget _bnbCard(BuildContext context, Obj u) {
    final st = unitStatus(u); final L = unitLease(u);
    final c = switch (st) { 'late' => const Color(0xFFE11D48), 'rent' => const Color(0xFF0F766E), _ => const Color(0xFF64748B) };
    final lbl = switch (st) { 'late' => 'متأخر', 'rent' => 'مؤجر', _ => 'فاضي' };
    return InkWell(onTap: () => Shell.go(1), child: Padding(padding: const EdgeInsets.only(bottom: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(height: 130, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Color.lerp(Colors.white, c, .14)), child: Stack(children: [
        Center(child: Icon(Icons.weekend_outlined, size: 54, color: c.withOpacity(.55))),
        PositionedDirectional(top: 10, start: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)), child: Text(lbl, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: c)))),
      ])),
      const SizedBox(height: 6),
      Text(Priv.un(u['name']), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
      Text(L == null ? 'مستني مستأجر' : (Priv.on ? '••••' : str(L['tenant'])), style: const TextStyle(color: kMuted, fontSize: 12.5)),
      if (L != null) Text.rich(TextSpan(children: [TextSpan(text: _m(n0(L['rent'])), style: const TextStyle(fontWeight: FontWeight.w900)), const TextSpan(text: ' درهم / شهر')]), style: const TextStyle(fontSize: 13.5)),
    ])));
  }
}


/// دوسة على حركة جاية → تتسجّل إنها اتدفعت (إيجار مستأجر أو قسط شركة)
Future<void> recordEv(BuildContext context, Map x) async {
  final t = x['_t']; final u = x['_u'];
  if (t == null || u is! Map<String, dynamic>) { toast(context, 'الحركة دي بتتسجّل من صفحتها'); return; }
  final amt = (x['a'] as num).abs();
  if (t == 'rent') {
    final ok = await confirmDlg(context, '✅ تسجّل إنك استلمت\n${str(x['l'])}\n${_m(amt)} درهم؟', ok: '✅ استلمت');
    if (!ok) return;
    await Act.rentPaid(u, x['_k'] as int, x['_i'] as int);
    if (context.mounted) toast(context, '✅ اتسجّل استلام ${_m(amt)}');
  } else if (t == 'inst') {
    final src = await pickDlg(context, '💳 دفعت ${str(x['l'])} (${_m(amt)}) منين؟', [['cash', 'من الرصيد'], ['gp', 'من فلوس الشراكة'], ['', 'من بره البرنامج']], 'cash');
    if (src == null) return;
    await Act.instPay(u, x['_i'] as int, src);
    if (context.mounted) toast(context, '✅ اتسجّلت دفعة الشركة');
  }
}

/// «كل التفاصيل»: باقي الداشبورد مقفول في زرار عشان الصفحة تبقى قصيرة
class MoreDetails extends StatefulWidget {
  final List<Widget> children;
  const MoreDetails({super.key, required this.children});
  @override
  State<MoreDetails> createState() => _MoreDetailsState();
}

class _MoreDetailsState extends State<MoreDetails> {
  static bool open = false;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(borderRadius: BorderRadius.circular(14), onTap: () => setState(() => open = !open), child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBd)),
          child: Row(children: [
            const Icon(Icons.insights_rounded, color: kAc, size: 20), const SizedBox(width: 8),
            Text(open ? 'اقفل التفاصيل' : 'كل التفاصيل والتحليلات', style: const TextStyle(fontWeight: FontWeight.w800, color: kNavy)),
            const Spacer(),
            AnimatedRotation(turns: open ? .5 : 0, duration: const Duration(milliseconds: 180), child: const Icon(Icons.expand_more, color: kMuted)),
          ]),
        )),
        if (open) ...[const SizedBox(height: 6), ...widget.children],
      ]);
}


/// 🏦 الحركات الجاية: فلوس داخلة/خارجة + تجديد عقد شركة قرّب + عقد عميل بيخلص — بباقي كام يوم
class BankMoves extends StatefulWidget {
  final Engine e;
  const BankMoves(this.e, {super.key});
  @override
  State<BankMoves> createState() => _BankMovesState();
}

class _BankMovesState extends State<BankMoves> {
  static bool all = false;
  List<Map<String, dynamic>> _list() {
    final t = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final L = <Map<String, dynamic>>[...widget.e.events()];
    for (final u in widget.e.SU()) {
      final ce = addM(pd(u['start']), n0(u['cm']));
      final nd = ce.difference(t).inDays;
      if (u['ren'] != 'no' && nd <= 60 && nd >= -30) L.add({'d': ce, 'l': '${str(u['name'])} – تجديد عقد الشركة', '_t': 'cren', '_u': u});
      final ls = objs(u['leases']);
      for (var k = 0; k < ls.length; k++) {
        final x = ls[k]; if (truthy(x['exit'])) continue;
        final le = Engine.lend(x); final ld = le.difference(t).inDays;
        if (ld <= 45 && ld >= -15) L.add({'d': le, 'l': '${str(u['name'])} – انتهاء عقد ${str(x['tenant']).isEmpty ? 'مستأجر' : str(x['tenant'])}', '_t': 'lend', '_u': u, '_L': x});
      }
    }
    L.sort((a, b) => (a['d'] as DateTime).compareTo(b['d'] as DateTime));
    return L;
  }

  static const _mn = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
  static int _days(DateTime d) { final t = DateTime.now(); return DateTime(d.year, d.month, d.day).difference(DateTime(t.year, t.month, t.day)).inDays; }
  static (String, Color) _bucket(int nd) => nd <= 0 ? ('النهارده', const Color(0xFFB91C1C)) : nd <= 7 ? ('الأسبوع ده', const Color(0xFFC2410C)) : nd <= 14 ? ('الأسبوع الجاي', const Color(0xFF15803D)) : nd <= 31 ? ('الشهر ده', const Color(0xFF1E3A8A)) : ('بعد كده', const Color(0xFF64748B));

  Widget _row(BuildContext context, Map<String, dynamic> x) {
    final d = x['d'] as DateTime; final nd = _days(d);
    final ty = x['_t']; final a = x['a'] as num?;
    final info = ty == 'cren' || ty == 'lend';
    final c = info ? (ty == 'cren' ? const Color(0xFF7C3AED) : const Color(0xFFD97706)) : (a! >= 0 ? const Color(0xFF15803D) : const Color(0xFFB91C1C));
    final (_, bc) = _bucket(nd);
    return InkWell(
      onTap: () {
        if (ty == 'cren') { Shell.go(1); return; }
        if (ty == 'lend') { Navigator.of(context).push(MaterialPageRoute(builder: (_) => LeaseEdit(x['_u'] as Obj, null, renew: x['_L'] as Obj))); return; }
        recordEv(context, x);
      },
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9), child: Row(children: [
        // التاريخ زي النتيجة: اليوم كبير والشهر تحته
        Container(width: 44, padding: const EdgeInsets.symmetric(vertical: 4), decoration: BoxDecoration(color: bc.withOpacity(.09), borderRadius: BorderRadius.circular(10)), child: Column(children: [
          Text('${d.day}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: bc, height: 1.1)),
          Text(_mn[d.month - 1], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: bc)),
        ])),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(Priv.on ? '••••' : str(x['l']).split(' – ').last, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: info ? c : kInk)),
          Text(Priv.on ? '••' : '${str(x['l']).split(' – ').first}${nd > 0 ? ' • باقي $nd يوم' : nd == 0 ? ' • النهارده' : ' • فات ${-nd} يوم'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: kMuted)),
        ])),
        const SizedBox(width: 6),
        info ? Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: c.withOpacity(.1), borderRadius: BorderRadius.circular(99)), child: Text('جدّد', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: c)))
            : Text('${a! >= 0 ? '+' : '-'}${_m(a.abs())}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: c)),
      ])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final L = _list(); const first = 5;
    final shown = all ? L : L.take(first).toList();
    // تجميع بالأسابيع
    final groups = <String, List<Map<String, dynamic>>>{}; final gc = <String, Color>{};
    for (final x in shown) { final (g, c) = _bucket(_days(x['d'] as DateTime)); groups.putIfAbsent(g, () => []).add(x); gc[g] = c; }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Padding(padding: EdgeInsets.only(bottom: 4, right: 4, left: 4), child: Row(children: [Text('الحركات الجاية', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)), Spacer(), Text('دوس على الحركة تسجّلها', style: TextStyle(color: kMuted, fontSize: 11.5))])),
      if (L.isEmpty) Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBd)), child: const Text('مفيش حركات جاية', style: TextStyle(color: kMuted))),
      for (final g in groups.entries) ...[
        Padding(padding: const EdgeInsets.fromLTRB(6, 8, 6, 5), child: Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: gc[g.key], shape: BoxShape.circle)), const SizedBox(width: 6),
          Text(g.key, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, color: gc[g.key])),
          const SizedBox(width: 6), Text('(${g.value.length})', style: const TextStyle(fontSize: 11.5, color: kMuted)),
        ])),
        Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBd)), child: Column(children: [
          for (var i = 0; i < g.value.length; i++) ...[if (i > 0) const Divider(height: 1, indent: 64), _row(context, g.value[i])],
        ])),
      ],
      if (L.length > first) Padding(padding: const EdgeInsets.only(top: 8), child: InkWell(borderRadius: BorderRadius.circular(12), onTap: () => setState(() => all = !all), child: Padding(padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(all ? 'اخفي الباقي' : 'شوف باقي الحركات (${L.length - first})', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A))), Icon(all ? Icons.expand_less : Icons.expand_more, color: const Color(0xFF1E3A8A))])))),
    ]);
  }
}
