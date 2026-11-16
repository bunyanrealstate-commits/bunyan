import 'package:flutter/material.dart';
import 'i18n.dart';
import '../core/store.dart';
import '../core/engine.dart';
import '../core/js.dart';
import 'theme.dart';
import 'shell.dart';

/// 🧮 المحاكي: أفتح استديو جديد؟ — نفس sim() في القديم
class SimPage extends StatefulWidget {
  const SimPage({super.key});
  @override
  State<SimPage> createState() => _SimState();
}

class _SimState extends State<SimPage> {
  static const F = [['fi', 'الدفعة الأولى للشركة (متوسط 8000)'], ['total', 'إجمالي إيجار الشركة طول العقد'], ['cm', 'مدة العقد (أشهر)'], ['n', 'عدد الدفعات'], ['furn', 'تكلفة الأثاث (متوسط 7000)'], ['salv', 'قيمة الأثاث اللي هتسترده آخر العقد'], ['rent', 'الإيجار الشهري المتوقع'], ['rm', 'أشهر هتتأجر فعلاً'], ['share', 'حصتي % (100 = لوحدك، 50 = مع شريك)'], ['me', 'من أموالي الخاصة (مش بيتخصم من النقدي)']];
  late final Map<String, dynamic> s;
  late final Map<String, TextEditingController> c;

  @override
  void initState() {
    super.initState();
    final S = Store.I.S;
    s = S['sim'] is Map<String, dynamic> ? S['sim'] as Map<String, dynamic> : (S['sim'] = <String, dynamic>{'total': 0, 'cm': 12, 'n': 4, 'furn': 0, 'share': 50, 'rent': 0, 'rm': 12});
    s['salv'] ??= 0; if (!truthy(s['fi'])) { s['fi'] = 8000; if (!truthy(s['furn'])) s['furn'] = 7000; } if (!truthy(s['share'])) s['share'] = 100; s['me'] ??= 0;
    c = {for (final f in F) f[0]: TextEditingController(text: '${s[f[0]] ?? 0}')};
  }

  void _ch(String k, String v) { final d = double.tryParse(v) ?? 0; s[k] = d == d.roundToDouble() ? d.toInt() : d; setState(() {}); }

  @override
  void dispose() { Store.I.save(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final e = Engine(Store.I.S, WS: Ws.I.resolve());
    final r = e.sim(s); final pw = r['pw'] as Map, pb = r['pb'] as Map;
    final f = n0(s['share']) / 100; final up = r['up'] as double, inj = r['inj'] as double, res = r['res'] as double;
    final pay = r['pay'] as int;
    String mn(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
    return Directionality(textDirection: L.dir, child: Scaffold(
      appBar: AppBar(title: Text(L.t('🧮 أفتح استديو جديد؟'))),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(color: r['has'] != true ? kSand : (r['ok'] == true ? const Color(0xFFE6F4EC) : const Color(0xFFFDECEA)), child: Padding(padding: const EdgeInsets.all(14), child: Text(
          r['has'] != true ? L.t('اكتب إجمالي إيجار الشركة والإيجار الشهري المتوقع علشان تشوف النتيجة.')
              : '${r['ok'] == true ? '✅ تقدر تفتحه. الرصيد مش هينزل تحت الاحتياطي حتى مع الدفعات الجاية.' : '⚠️ مش مناسب دلوقتي. الرصيد هينزل ${money(res - (pw['min'] as double))} تحت الاحتياطي في ${mn(pw['minD'] as DateTime)}.'}${r['low'] == true ? ' وربح الاستديو أقل من هدفك.' : ''}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _st(L.t('المبلغ المطلوب دلوقتي'), money(up), 'دفعة أولى + أثاث${f < 1 ? ' (حصتك)' : ''}${inj > 0 ? ' • من النقدي ${money(up - inj)} ومن أموالي ${money(inj)}' : ''}'),
          _st(L.t('إجمالي ربح الاستديو'), money(r['gain'] as double), L.t('آخر العقد'), cv: r['gain'] as double),
          _st(L.t('متوسط الربح الشهري'), money(r['mavg'] as double), '', cv: r['mavg'] as double),
          _st(L.t('العائد على الاستثمار'), up > 0 ? '${(r['roi'] as double).toStringAsFixed(0)}%' : '—', '', cv: r['roi'] as double),
          _st(L.t('استرداد الفلوس'), pay < 0 ? L.t('مش هيتسدد') : pay == 0 ? L.t('فوراً') : 'بعد $pay شهر', L.t('لحد ما الاستديو يرجّع اللي اتصرف'), cv: pay < 0 ? -1 : null),
          _st(L.t('أقل رصيد بعد الاستديو'), money(pw['min'] as double), '${mn(pw['minD'] as DateTime)}${pb['min'] != pw['min'] ? ' • من غيره ${money(pb['min'] as double)}' : ''}', cv: (pw['min'] as double) - res),
          _st(L.t('أقل إيجار شهري يحقق هدفك'), money(r['mr'] as double), 'هدف الربح ${(r['tp'] as double).round()}%'),
        ]),
        const SizedBox(height: 10),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(L.t('رصيدي: مع الاستديو ومن غيره'), style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          SizedBox(height: 180, child: CustomPaint(size: Size.infinite, painter: _Chart(e.cashNow(), pw['rows'] as List, pb['rows'] as List, res))),
          Text(L.t('الخط الأخضر = لو فتحته • الرمادي = من غيره • الأحمر المنقط = الاحتياطي'), style: TextStyle(fontSize: 12, color: kMuted)),
        ]))),
        const SizedBox(height: 6),
        Text(L.t('بيانات الاستديو'), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        const SizedBox(height: 6),
        for (final x in F) Padding(padding: const EdgeInsets.only(bottom: 8), child: TextField(controller: c[x[0]], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: x[1], border: const OutlineInputBorder(), isDense: true), onChanged: (v) => _ch(x[0], v))),
      ]),
    ));
  }

  Widget _st(String l, String v, String sub, {double? cv}) => SizedBox(width: 170, child: Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: const TextStyle(fontSize: 12, color: kMuted, fontWeight: FontWeight.bold)),
        Text(v, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: cv == null ? kInk : sign(cv))),
        if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 11, color: kMuted)),
      ]))));
}

class _Chart extends CustomPainter {
  final double now, res; final List A, B;
  _Chart(this.now, this.A, this.B, this.res);
  @override
  void paint(Canvas c, Size sz) {
    final t0 = today().millisecondsSinceEpoch.toDouble();
    List<Offset> pts(List r) => [Offset(t0, now), for (final x in r) Offset(((x as Map)['d'] as DateTime).millisecondsSinceEpoch.toDouble(), x['end'] as double)];
    final a = pts(A), b = pts(B); final all = [...a, ...b];
    final lo = [0.0, res, ...all.map((p) => p.dy)].reduce((x, y) => x < y ? x : y), hi = [1.0, res, ...all.map((p) => p.dy)].reduce((x, y) => x > y ? x : y);
    final t1 = [t0 + 1, ...all.map((p) => p.dx)].reduce((x, y) => x > y ? x : y);
    if (b.length < 2) b.add(Offset(t1, b[0].dy));
    Offset m(Offset p) => Offset(sz.width * (1 - (p.dx - t0) / (t1 - t0)), sz.height * (1 - (p.dy - lo) / ((hi - lo) == 0 ? 1 : hi - lo))); // RTL: الآن يمين
    Path pa(List<Offset> l) { final p = Path(); for (var i = 0; i < l.length; i++) { final q = m(l[i]); i == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy); } return p; }
    final y0 = m(Offset(t0, 0)).dy; c.drawLine(Offset(0, y0), Offset(sz.width, y0), Paint()..color = Colors.grey.shade400);
    if (res > 0) { final yr = m(Offset(t0, res)).dy; for (var x = 0.0; x < sz.width; x += 8) { c.drawLine(Offset(x, yr), Offset(x + 4, yr), Paint()..color = kRed..strokeWidth = 1.2); } }
    c.drawPath(pa(b), Paint()..color = Colors.grey..style = PaintingStyle.stroke..strokeWidth = 2);
    c.drawPath(pa(a), Paint()..color = kGreen..style = PaintingStyle.stroke..strokeWidth = 3);
  }
  @override
  bool shouldRepaint(covariant CustomPainter o) => true;
}
