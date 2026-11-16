import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/store.dart';
import '../core/js.dart';

/// ألوان بنيان (نفس البرنامج القديم)
const kAc = Color(0xFF1473E6), kAcD = Color(0xFF126AD3), kInk = Color(0xFF0E0F12), kMuted = Color(0xFF62646D), kBg = Color(0xFFEAF6F3), kBd = Color(0xFFD6D7DD),
    kOk = Color(0xFF16A34A), kGreen = Color(0xFF15924A), kRed = Color(0xFFD93D42), kTeal = Color(0xFF0D9488), kNavy = Color(0xFF1B4764);
// أسماء قديمة لسه مستخدمة
const kPaper = kBg, kSand = Color(0xFFF1F3F7), kTerra = Color(0xFFEA580C);

/// ألوان الكروت (كل كارت لونه)
const kCC = [Color(0xFF2563EB), Color(0xFF16A34A), Color(0xFF7C3AED), Color(0xFFEA580C), Color(0xFF0D9488), Color(0xFFDB2777), Color(0xFFB45309), Color(0xFF0891B2)];

ThemeData bunyanTheme() => ThemeData(
      useMaterial3: true,
      fontFamily: 'Plex',
      colorScheme: ColorScheme.fromSeed(seedColor: kAc, primary: kAc, secondary: kTeal, surface: Colors.white),
      scaffoldBackgroundColor: kBg,
      appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: kInk, elevation: 0, scrolledUnderElevation: 1, centerTitle: false, surfaceTintColor: Colors.white, titleTextStyle: TextStyle(fontFamily: 'Plex', fontSize: 18, fontWeight: FontWeight.w700, color: kInk)),
      cardTheme: CardTheme(color: Colors.white, elevation: 0, margin: const EdgeInsets.symmetric(vertical: 5), shadowColor: const Color(0x1A14213D), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE3E6EC)))),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: kAc, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)), textStyle: const TextStyle(fontFamily: 'Plex', fontWeight: FontWeight.w700))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: kInk, side: const BorderSide(color: kBd), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)), textStyle: const TextStyle(fontFamily: 'Plex', fontWeight: FontWeight.w700))),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: kAc, foregroundColor: Colors.white),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBd)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBd))),
      chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)), side: const BorderSide(color: kBd), selectedColor: kAc, labelStyle: const TextStyle(fontFamily: 'Plex', fontWeight: FontWeight.w700)),
      dividerTheme: const DividerThemeData(color: Color(0xFFE3E6EC)),
    );

final _nf = NumberFormat('#,##0', 'en');
/// زي $() في بنيان: رقم بالدرهم
String money(num v) { if (Priv.on) return '•••••'; final r = v.isNaN ? 0 : v.round(); return '${r < 0 ? '-' : ''}${_nf.format(r.abs())}'; }

/// 👁 العين: إخفاء الأرقام وأسماء الاستديوهات (زي القديم)
class Priv {
  static bool get on => Store.I.cfg['hide'] == true;
  /// اسم الاستديو
  static String un(dynamic name) => on ? '••••' : str(name);
  /// نص فيه أسماء استديوهات (زي التنبيهات)
  static String txt(String s) {
    if (!on) return s;
    var o = s; for (final u in objs(Store.I.S['units'])) { final n = str(u['name']); if (n.length > 1) o = o.replaceAll(n, '••••'); }
    return o.replaceAll(RegExp(r'\d[\d,]{2,}'), '•••');
  }
}
Color sign(num v) => v < 0 ? kRed : kGreen;

/// كارت بنيان: شريط ملوّن فوق + لون خفيف + عنوان بنفس اللون (زي cardsep في القديم)
class BCard extends StatelessWidget {
  final Color c; final String? title; final Widget child; final EdgeInsets pad; final Widget? trailing;
  const BCard({super.key, this.c = const Color(0xFF2563EB), this.title, required this.child, this.pad = const EdgeInsets.fromLTRB(14, 12, 14, 14), this.trailing});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: c.withOpacity(.22), blurRadius: 22, offset: const Offset(0, 8), spreadRadius: -8), const BoxShadow(color: Color(0x0F0F2742), blurRadius: 2, offset: Offset(0, 1))]),
        child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Container(
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.alphaBlend(c.withOpacity(.09), Colors.white), Colors.white], stops: const [0, .35]), border: Border.all(color: Color.alphaBlend(c.withOpacity(.30), kBd), width: 1.2)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(height: 6, color: c),
            Padding(padding: pad, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (title != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
                Container(width: 4, height: 18, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))), const SizedBox(width: 8),
                Expanded(child: Text(title!, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color.alphaBlend(kInk.withOpacity(.2), c)))),
                if (trailing != null) trailing!,
              ])),
              child,
            ])),
          ]),
        )),
      );
}

/// مربع رقم (stat) — خلفية بلون خفيف وشريط على الجنب
class BStat extends StatelessWidget {
  final String l; final double v; final String? sub; final Color? c; final String? text;
  const BStat(this.l, this.v, {super.key, this.sub, this.c, this.text});
  @override
  Widget build(BuildContext context) {
    final col = c ?? (v < 0 ? kRed : kOk);
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: col.withOpacity(.35), blurRadius: 16, offset: const Offset(0, 6), spreadRadius: -8)]),
      child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Container(
        color: Color.alphaBlend(col.withOpacity(.08), Colors.white),
        child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 6, color: col),
          Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l, style: const TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(text != null ? (Priv.on ? '•••' : text!) : money(v), style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Color.alphaBlend(Colors.black.withOpacity(.08), col))),
            if (sub != null) Text(sub!, style: const TextStyle(color: kMuted, fontSize: 11)),
          ]))),
        ])),
      )),
    );
  }
}
