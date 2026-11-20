/// 🎨 قطع الداشبورد بنفس شكل بنيان القديم (المنظر المرسوم، كروت الحالة، خطة السحب، ربح كل استديو…)
/// + الهيدر: الجرس، الساعة، وقايمة المجموعات المودرن
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'i18n.dart';
import '../core/store.dart';
import '../core/engine.dart';
import '../core/js.dart';
import 'theme.dart';
import 'shell.dart';
import 'units.dart';
import 'forecast.dart';
import 'notif.dart';

/* ───────── عنوان قسم (اللمسة التنظيمية: الداشبورد متقسم أقسام واضحة) ───────── */
class SecHead extends StatelessWidget {
  final String t; final String? sub;
  const SecHead(this.t, {super.key, this.sub});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
        child: Row(children: [
          Container(width: 4, height: 18, margin: const EdgeInsetsDirectional.only(end: 7), decoration: BoxDecoration(color: kAc, borderRadius: BorderRadius.circular(9))),
          Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: kNavy)),
          if (sub != null) Padding(padding: const EdgeInsetsDirectional.only(start: 6), child: Text(sub!, style: const TextStyle(fontSize: 12, color: kMuted, fontWeight: FontWeight.w600))),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1.4, decoration: BoxDecoration(gradient: LinearGradient(colors: [kNavy.withOpacity(.28), kNavy.withOpacity(0)])))),
        ]),
      );
}

/* ───────── المنظر المرسوم فوق (زي القديم: سما، شمس، سحاب، عماير، بيت، نخل) ───────── */
class HeroScene extends StatelessWidget {
  const HeroScene({super.key});
  @override
  Widget build(BuildContext context) {
    final h = DateTime.now().hour; final nm = str(Store.I.cfg['u']);
    final g = h < 12 ? Tr.t('صباح الخير') : Tr.t('مساء الخير');
    const ms = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    const ds = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    final t = DateTime.now();
    return Container(
      height: 118, margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), boxShadow: const [BoxShadow(color: Color(0x2614213D), blurRadius: 18, offset: Offset(0, 8), spreadRadius: -6)]),
      child: ClipRRect(borderRadius: BorderRadius.circular(22), child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _Scene())),
        PositionedDirectional(start: 12, top: 12, child: ClipRRect(borderRadius: BorderRadius.circular(16), child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6), child: Container(
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 10),
          decoration: BoxDecoration(color: Colors.white.withOpacity(.80), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(.9))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('$g${nm.isEmpty ? '' : '، $nm'} 👋', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: kNavy)),
            const SizedBox(height: 2),
            Text(Tr.en ? '${t.day}/${t.month}/${t.year}' : '${ds[t.weekday - 1]}، ${t.day} ${ms[t.month - 1]}', style: const TextStyle(color: Color(0xFF3B4250), fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        )))),
      ])),
    );
  }
}

class _Scene extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final W = s.width, H = s.height, gy = H - 12;
    // السما
    c.drawRect(Offset.zero & s, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2E6F8E), Color(0xFF7DBBD0), Color(0xFFEAF2EE)], stops: [0, .55, 1]).createShader(Offset.zero & s));
    // الشمس + هالة
    final sc = Offset(W * .36, H * .30);
    c.drawCircle(sc, 46, Paint()..shader = RadialGradient(colors: [const Color(0xFFFFE07A).withOpacity(.85), const Color(0xFFFFE07A).withOpacity(0)]).createShader(Rect.fromCircle(center: sc, radius: 46)));
    c.drawCircle(sc, 19, Paint()..color = const Color(0xFFFFE79A));
    c.drawCircle(sc, 19, Paint()..color = const Color(0xFFFFC94A)..style = PaintingStyle.stroke..strokeWidth = 3);
    // سحابة
    final cl = Paint()..color = Colors.white.withOpacity(.85);
    c.drawOval(Rect.fromLTWH(-18, H * .18, 70, 22), cl); c.drawOval(Rect.fromLTWH(14, H * .12, 40, 24), cl);
    // عماير شمال
    _tower(c, 10, gy, 40, 66, const Color(0xFF1E4B66), 4);
    _tower(c, 56, gy, 50, 50, const Color(0xFF2B6E86), 5);
    // البيت الأبيض في النص
    final hx = W * .30, hw = W * .30, hy = gy - 54;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(hx, hy, hw, 54), const Radius.circular(3)), Paint()..color = Colors.white);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(hx - 6, hy - 8, hw + 12, 9), const Radius.circular(6)), Paint()..color = const Color(0xFF13896F));
    final wy = hy + 9; final ww = (hw - 24) / 3;
    for (var i = 0; i < 3; i++) {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(hx + 6 + i * (ww + 6), wy, ww, 20), const Radius.circular(3)), Paint()..color = i == 2 ? const Color(0xFFFCE3A8) : const Color(0xFFBFE3F7));
    }
    c.drawRect(Rect.fromLTWH(hx + 4, wy + 25, hw - 8, 2.5), Paint()..color = const Color(0xFF7FB9AE));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(hx + hw / 2 - 9, gy - 17, 18, 17), const Radius.circular(2)), Paint()..color = const Color(0xFF13896F));
    c.drawCircle(Offset(hx + hw / 2 + 4, gy - 8), 1.6, Paint()..color = const Color(0xFFFFD34D));
    // عماير يمين
    _tower(c, W * .63, gy, 36, 78, const Color(0xFF1E4B66), 3);
    _tower(c, W * .63 + 42, gy, 46, 58, const Color(0xFF2B6E86), 4);
    // نخل
    _palm(c, W - 46, gy, 64); _palm(c, W - 16, gy, 48);
    // الأرض
    c.drawRect(Rect.fromLTWH(0, gy, W, H - gy), Paint()..color = const Color(0xFF15806A));
    c.drawRect(Rect.fromLTWH(0, gy - 2, W, 3), Paint()..color = const Color(0xFF2AA889));
  }

  void _tower(Canvas c, double x, double gy, double w, double h, Color col, int cols) {
    c.drawRRect(RRect.fromRectAndCorners(Rect.fromLTWH(x, gy - h, w, h), topLeft: const Radius.circular(3), topRight: const Radius.circular(3)), Paint()..color = col);
    final cw = (w - 6) / cols; final rows = ((h - 8) / 10).floor();
    final r = math.Random(x.toInt() * 7 + h.toInt());
    for (var j = 0; j < rows; j++) {
      for (var i = 0; i < cols; i++) {
        final lit = r.nextDouble() > .45;
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 4 + i * cw, gy - h + 5 + j * 10, cw - 3, 6), const Radius.circular(1)), Paint()..color = lit ? const Color(0xFFFFD45C) : const Color(0xFF8CC5E6));
      }
    }
  }

  void _palm(Canvas c, double x, double gy, double h) {
    final tr = Path()..moveTo(x, gy)..quadraticBezierTo(x + 6, gy - h * .5, x - 2, gy - h);
    c.drawPath(tr, Paint()..color = const Color(0xFF7A5230)..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round);
    final top = Offset(x - 2, gy - h); final lf = Paint()..color = const Color(0xFF1F9D5A)..style = PaintingStyle.stroke..strokeWidth = 4.5..strokeCap = StrokeCap.round;
    for (final a in [-2.6, -2.0, -1.2, -0.5, 0.2]) {
      final e = top + Offset(math.cos(a) * 22, math.sin(a) * 12 + 8);
      c.drawPath(Path()..moveTo(top.dx, top.dy)..quadraticBezierTo(top.dx + math.cos(a) * 12, top.dy - 8, e.dx, e.dy), lf);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

/* ───────── مربعات الحالة: مؤجر / شاغر / متأخر (دوس عليها تفتح الاستديوهات) ───────── */
class StatusTiles extends StatelessWidget {
  final Engine e;
  const StatusTiles(this.e, {super.key});
  @override
  Widget build(BuildContext context) {
    final us = e.SU(); final sts = us.map(unitStatus).toList();
    Widget tile(String ic, String l, int n, Color c) => Expanded(child: InkWell(
          borderRadius: BorderRadius.circular(18), onTap: () => Shell.go(1),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFD5E8E2)), boxShadow: const [BoxShadow(color: Color(0x1214213D), blurRadius: 12, offset: Offset(0, 4))]),
            child: Column(children: [
              Text(Priv.on ? '•' : '$n', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: c, height: 1.1)),
              const SizedBox(height: 4),
              Text('$ic $l', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF3B4250))),
            ]),
          ),
        ));
    return Row(children: [
      tile('🟢', Tr.t('مؤجر'), sts.where((s) => s == 'rent').length, kGreen), const SizedBox(width: 10),
      tile('⚪', Tr.t('شاغر'), sts.where((s) => s == 'vac').length, kMuted), const SizedBox(width: 10),
      tile('🔴', Tr.t('متأخر'), sts.where((s) => s == 'late').length, kRed),
    ]);
  }
}

/* ───────── خطة السحب: «تقدر تسحب دلوقتي من غير عجز» ───────── */
class WithdrawCard extends StatelessWidget {
  final Engine e;
  const WithdrawCard(this.e, {super.key});
  @override
  Widget build(BuildContext context) {
    final ev = e.events(); if (ev.isEmpty) return const SizedBox.shrink();
    final p = e.project(ev); final min = p['min'] as double; final minD = p['minD'] as DateTime;
    final res = n0(Store.I.S['res']); final now = math.max(0.0, min - res);
    const ms = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    final ok = now > 0;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForecastPage())),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: const Color(0xFFF3F6FD), border: Border.all(color: const Color(0xFFC9D6F2)), boxShadow: const [BoxShadow(color: Color(0x1A2563EB), blurRadius: 16, offset: Offset(0, 6), spreadRadius: -6)]),
        child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(height: 5, color: const Color(0xFF2563EB)),
          Padding(padding: const EdgeInsets.fromLTRB(14, 12, 10, 14), child: Row(children: [
            const Text('🧭', style: TextStyle(fontSize: 26)), const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: Tr.t('تقدر تسحب دلوقتي من غير عجز: '), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: kInk)),
                TextSpan(text: money(now), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: ok ? kGreen : kRed)),
              ])),
              const SizedBox(height: 4),
              Text('${Tr.t('أقل رصيد هيوصله')} ${money(min)} ${Tr.t('يوم')} ${minD.day} ${ms[minD.month - 1]} ${minD.year} • ${Tr.t('اضغط لخطة السحب')}', style: const TextStyle(color: Color(0xFF4A5060), fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.5)),
            ])),
            const Icon(Icons.chevron_left, color: kMuted),
          ])),
        ])),
      ),
    );
  }
}

/* ───────── الإيجارات وصافي ربح كل استديو (شهري) — زي upc() في القديم ───────── */
class PerUnitCard extends StatelessWidget {
  final Engine e;
  const PerUnitCard(this.e, {super.key});
  double _mp(Obj u, Obj L) {
    final lm = Engine.lm(L); final cm = n0(u['cm']);
    return (n0(L['rent']) + n0(L['inet']) - n0(L['icost']) - (truthy(L['rme']) ? n0(L['router']) / (lm == 0 ? 1 : lm) : 0) - (e.ua(u)['full']! + n0(u['salv'])) / (cm == 0 ? 1 : cm)) * e.sh(u);
  }
  @override
  Widget build(BuildContext context) {
    final us = e.SU(); if (us.isEmpty) return const SizedBox.shrink();
    var R = 0.0, P = 0.0; final rows = <Widget>[];
    for (final u in us) {
      final L = unitLease(u); final cm = n0(u['cm']);
      final r = L == null ? 0.0 : n0(L['rent']) + n0(L['inet']);
      final pr = L != null ? _mp(u, L) : -((e.ua(u)['full']! + n0(u['salv'])) / (cm == 0 ? 1 : cm)) * e.sh(u);
      R += r * (L != null ? e.sh(u) : 0); P += pr;
      rows.add(Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFDDEBE6)))),
        child: Row(children: [
          Expanded(child: Text.rich(TextSpan(children: [
            TextSpan(text: Priv.un(u['name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: kInk)),
            TextSpan(text: ' • ${L == null ? Tr.t('شاغر') : str(L['tenant'])}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kMuted)),
          ]), overflow: TextOverflow.ellipsis)),
          SizedBox(width: 70, child: Text(L == null ? '—' : money(r * e.sh(u)), style: const TextStyle(color: Color(0xFF4A5060), fontWeight: FontWeight.w700))),
          SizedBox(width: 70, child: Text(money(pr), textAlign: TextAlign.left, style: TextStyle(fontWeight: FontWeight.w900, color: sign(pr)))),
        ]),
      ));
    }
    Widget kv(String l, double v, Color c) => Expanded(child: Container(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
          decoration: BoxDecoration(color: const Color(0xFFF3FAF7), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFCFE6DE))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 12.5, color: Color(0xFF4A5060), fontWeight: FontWeight.w600)), Text(money(v), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: c))]),
        ));
    return BCard(c: kTerra, title: '🏠 ${Tr.t('الإيجارات وصافي ربح كل استديو')}', trailing: Text(Tr.t('(شهري)'), style: const TextStyle(color: kMuted, fontWeight: FontWeight.w700, fontSize: 12.5)), child: Column(children: [
      Row(children: [kv(Tr.t('إجمالي الإيجارات'), R, kInk), const SizedBox(width: 10), kv(Tr.t('صافي الربح'), P, sign(P))]),
      const SizedBox(height: 4),
      Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [
        Expanded(child: Text(Tr.t('الاستديو'), style: const TextStyle(fontSize: 11.5, color: kMuted, fontWeight: FontWeight.w700))),
        SizedBox(width: 70, child: Text(Tr.t('الإيجار'), style: const TextStyle(fontSize: 11.5, color: kMuted, fontWeight: FontWeight.w700))),
        SizedBox(width: 70, child: Text(Tr.t('الربح'), textAlign: TextAlign.left, style: const TextStyle(fontSize: 11.5, color: kMuted, fontWeight: FontWeight.w700))),
      ])),
      ...rows,
    ]));
  }
}

/* ───────── رأس مال أول المدة ───────── */
class CapitalCard extends StatelessWidget {
  const CapitalCard({super.key});
  @override
  Widget build(BuildContext context) {
    final w = Ws.I.resolve(); final v = n0(obj(Store.I.S['obal'])?[w]);
    if (v == 0) return const SizedBox.shrink();
    return BCard(c: kTeal, child: Row(children: [
      const Text('🏁', style: TextStyle(fontSize: 26)), const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text.rich(TextSpan(children: [TextSpan(text: Tr.t('رأس مال أول المدة: '), style: const TextStyle(fontWeight: FontWeight.w800, color: kNavy, fontSize: 15)), TextSpan(text: money(v), style: const TextStyle(fontWeight: FontWeight.w900, color: kNavy, fontSize: 17))])),
        const SizedBox(height: 4),
        Text(Tr.t('فلوس إيجارات معاك للاستديوهات الشغالة — بتدخل الرصيد النقدي كرأس مال، مش ربح.'), style: const TextStyle(color: Color(0xFF4A5060), fontSize: 12.5, height: 1.5)),
      ])),
    ]));
  }
}

/* ───────── 🔔 الجرس: عدد التنبيهات وقايمتها ───────── */
class BellBtn extends StatelessWidget {
  const BellBtn({super.key});
  @override
  Widget build(BuildContext context) {
    // زي القديم: العدد = تنبيهات النهارده + المتأخر، والجرس بيحمرّ لو فيه متأخر
    final e = Engine(Store.I.S, WS: Ws.I.resolve());
    final al = alertsNow(e).length, od = overdueN(e), tot = al + od;
    final c = od > 0 ? kRed : al > 0 ? kTerra : null;
    return Stack(clipBehavior: Clip.none, children: [
      InkWell(
        borderRadius: BorderRadius.circular(12), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotifPage())),
        child: Container(width: 36, height: 36, decoration: BoxDecoration(color: c ?? const Color(0xFFF4F5F8), borderRadius: BorderRadius.circular(12), border: Border.all(color: c ?? const Color(0xFFD6D9E0))), child: Icon(tot > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, size: 21, color: c == null ? kInk : Colors.white)),
      ),
      Positioned(top: -5, right: -5, child: Container(
        constraints: const BoxConstraints(minWidth: 18), height: 18, padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(color: tot == 0 ? const Color(0xFF8A93A3) : kRed, borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white, width: 1.5)),
        alignment: Alignment.center, child: Text('$tot', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900)),
      )),
    ]);
  }
}

/* ───────── 🕒 الساعة في الهيدر ───────── */
class HdClock extends StatefulWidget {
  const HdClock({super.key});
  @override
  State<HdClock> createState() => _HdClockState();
}

class _HdClockState extends State<HdClock> {
  Timer? _t;
  @override
  void initState() { super.initState(); _t = Timer.periodic(const Duration(seconds: 20), (_) { if (mounted) setState(() {}); }); }
  @override
  void dispose() { _t?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final n = DateTime.now(); final h = n.hour % 12 == 0 ? 12 : n.hour % 12;
    return Directionality(textDirection: TextDirection.ltr, child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text('$h:${n.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: kInk, height: 1)),
      const SizedBox(width: 2),
      Text(n.hour < 12 ? 'AM' : 'PM', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kAc, height: 1.4)),
    ]));
  }
}

/* ───────── 📂 زرار المجموعة + القايمة المودرن ───────── */
const _gCol = [[Color(0xFF14B8A6), Color(0xFF0F766E)], [Color(0xFF334E68), Color(0xFF14304A)], [Color(0xFFE0A84A), Color(0xFFB7791F)], [Color(0xFF6366F1), Color(0xFF4338CA)], [Color(0xFF0EA5E9), Color(0xFF0369A1)], [Color(0xFFF43F5E), Color(0xFFBE123C)]];
String _ini(String n) {
  final w = n.replaceFirst(RegExp(r'^مع\s+'), '').trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
  final o = <String>[]; for (var i = 0; i < w.length && o.length < 2; i++) { var x = w[i]; if (i > 0 && x.length > 1 && x.startsWith('و')) x = x.substring(1); o.add(x.characters.first); }
  return o.isEmpty ? '•' : o.join('‌');
}

class GroupPill extends StatelessWidget {
  const GroupPill({super.key});
  @override
  Widget build(BuildContext context) {
    final S = Store.I.S; final gs = objs(S['groups']);
    final noG = objs(S['units']).any((u) => !truthy(u['g']));
    if (gs.isEmpty && !noG) return const SizedBox();
    final cur = Ws.I.resolve();
    final name = cur == '-' ? Tr.t('بدون مجموعة') : str(gs.where((g) => g['id'] == cur).firstOrNull?['name']);
    return InkWell(
      borderRadius: BorderRadius.circular(99), onTap: () => openGroups(context),
      child: Container(
        height: 32, padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0D8A74), Color(0xFF14B8A6)]), borderRadius: BorderRadius.circular(99), boxShadow: const [BoxShadow(color: Color(0x4014B8A6), blurRadius: 12, offset: Offset(0, 4))]),
        child: Row(children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: const Color(0xFFBFFFE9), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.white.withOpacity(.7), blurRadius: 4)])),
          const SizedBox(width: 6),
          // الاسم بيصغر لوحده لو المكان ضيق (بدل ما يتقطع)
          Expanded(child: Ticker(Priv.on ? '••••' : name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5))),
          const SizedBox(width: 2), const Icon(Icons.expand_more, color: Colors.white, size: 16),
        ]),
      ),
    );
  }
}

Future<void> openGroups(BuildContext context) async {
  final S = Store.I.S; final gs = objs(S['groups']); final us = objs(S['units']);
  final cur = Ws.I.resolve();
  final opts = <List<String>>[for (final g in gs) [str(g['id']), str(g['name'])], if (us.any((u) => !truthy(u['g']))) ['-', Tr.t('بدون مجموعة')]];
  final v = await showGeneralDialog<String>(
    context: context, barrierDismissible: true, barrierLabel: 'x', barrierColor: const Color(0x470F172A), transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, __) => Directionality(textDirection: Tr.dir, child: SafeArea(child: Align(alignment: Alignment.topCenter, child: Padding(
      padding: const EdgeInsets.only(top: 60, left: 14, right: 14),
      child: Material(color: Colors.transparent, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 320), child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0x40949FB8)), boxShadow: const [BoxShadow(color: Color(0x590F172A), blurRadius: 50, offset: Offset(0, 22), spreadRadius: -12)]),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.fromLTRB(10, 6, 10, 10), child: Row(children: [const Icon(Icons.groups_2_outlined, size: 18, color: kAc), const SizedBox(width: 6), Text(Tr.t('اختار المجموعة'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kNavy))])),
          for (var i = 0; i < opts.length; i++) Builder(builder: (_) {
            final o = opts[i]; final on = o[0] == cur; final c = _gCol[i % _gCol.length];
            final nUnits = us.where((u) => o[0] == '-' ? !truthy(u['g']) : u['g'] == o[0]).length;
            return InkWell(
              borderRadius: BorderRadius.circular(15), onTap: () => Navigator.of(ctx).pop(o[0]),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: on ? const Color(0xFFE6F4F1) : null, border: Border.all(color: on ? const Color(0xFF99D5CB) : Colors.transparent)),
                child: Row(children: [
                  Container(width: 36, height: 36, alignment: Alignment.center, decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: o[0] == '-' ? const [Color(0xFF94A3B8), Color(0xFF64748B)] : c), boxShadow: [BoxShadow(color: c[1].withOpacity(.35), blurRadius: 10, offset: const Offset(0, 4), spreadRadius: -3)]),
                    child: Text(Priv.on ? '•' : _ini(o[1]), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(Priv.on ? '••••' : o[1], overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: on ? kAcD : kNavy)),
                    Text('$nUnits ${Tr.t('استديو')}', style: const TextStyle(fontSize: 12, color: kMuted, fontWeight: FontWeight.w600)),
                  ])),
                  if (on) Container(width: 22, height: 22, decoration: const BoxDecoration(color: kAc, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, color: Colors.white, size: 16)),
                ]),
              ),
            );
          }),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Divider(height: 1)),
          InkWell(
            borderRadius: BorderRadius.circular(15), onTap: () => Navigator.of(ctx).pop('__m'),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.tune_rounded, size: 20, color: kMuted)),
              const SizedBox(width: 12),
              Text(Tr.t('إدارة المجموعات'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kMuted)),
            ])),
          ),
        ]),
      ))),
    )))),
    transitionBuilder: (ctx, a, _, child) {
      final cv = CurvedAnimation(parent: a, curve: Curves.easeOutBack);
      return BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 3 * a.value, sigmaY: 3 * a.value), child: FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: .96, end: 1.0).animate(cv), alignment: Alignment.topCenter, child: child)));
    },
  );
  if (v == null || !context.mounted) return;
  if (v == '__m') { Shell.go(4); return; }
  Ws.I.pick(v);
}


/// اسم بيمشي جوه مكانه (شريط متحرك) — بيلف على طول بهدوء
class Ticker extends StatefulWidget {
  final String text; final TextStyle style;
  const Ticker(this.text, {super.key, required this.style});
  @override
  State<Ticker> createState() => _TickerState();
}

class _TickerState extends State<Ticker> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  @override
  void dispose() { a.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, bc) {
        final tp = TextPainter(text: TextSpan(text: widget.text, style: widget.style), textDirection: Directionality.of(context), maxLines: 1)..layout();
        final W = bc.maxWidth, tw = tp.width, travel = W + tw;
        final d = Duration(milliseconds: (travel * 16).round().clamp(1600, 9000)); // ~60 بكسل في الثانية
        if (a.duration != d) { a.duration = d; a.repeat(); }
        final rtl = Directionality.of(context) == TextDirection.rtl;
        // نسخة واحدة بس: بتدخل من ناحية وتطلع من الناحية التانية
        return ClipRect(child: AnimatedBuilder(animation: a, builder: (_, __) {
          final x = rtl ? -tw + a.value * travel : W - a.value * travel;
          return Stack(clipBehavior: Clip.hardEdge, children: [Positioned(left: x, top: 0, bottom: 0, child: Center(child: Text(widget.text, maxLines: 1, softWrap: false, style: widget.style)))]);
        }));
      });
}
