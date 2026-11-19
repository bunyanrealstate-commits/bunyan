import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/store.dart';
import '../core/js.dart';

/// 🎨 ألوان بنيان الجديدة: كحلي غامق + تيل (أخضر مزرق) + دهبي — هادية وفخمة ومريحة للعين
const kAc = Color(0xFF0F766E), kAcD = Color(0xFF115E59), kInk = Color(0xFF0F172A), kMuted = Color(0xFF64748B), kBg = Color(0xFFF3F5F8), kBd = Color(0xFFE2E8F0),
    kOk = Color(0xFF059669), kGreen = Color(0xFF047857), kRed = Color(0xFFDC2626), kTeal = Color(0xFF0D9488), kNavy = Color(0xFF14304A);
// أسماء قديمة لسه مستخدمة
const kPaper = kBg, kSand = Color(0xFFF1F5F9), kTerra = Color(0xFFD97706), kGold = Color(0xFFC08A2E);

/// ألوان الكروت (متناسقة مع بعض)
const kCC = [Color(0xFF0F766E), Color(0xFF4F46E5), Color(0xFFD97706), Color(0xFF0284C7), Color(0xFF7C3AED), Color(0xFFE11D48), Color(0xFF059669), Color(0xFF475569)];

ThemeData bunyanTheme() => ThemeData(
      useMaterial3: true,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      fontFamily: 'Plex',
      colorScheme: ColorScheme.fromSeed(seedColor: kAc, primary: kAc, secondary: kTeal, surface: Colors.white),
      scaffoldBackgroundColor: kBg,
      appBarTheme: const AppBarTheme(backgroundColor: Colors.white, shadowColor: Color(0x1414304A), foregroundColor: kInk, elevation: 0, scrolledUnderElevation: 1, centerTitle: false, surfaceTintColor: Colors.white, titleTextStyle: TextStyle(fontFamily: 'Plex', fontSize: 18, fontWeight: FontWeight.w700, color: kInk)),
      cardTheme: CardTheme(color: Colors.white, elevation: 0, margin: const EdgeInsets.symmetric(vertical: 5), shadowColor: const Color(0x1414304A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE3E6EC)))),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: kAc, minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)), textStyle: const TextStyle(fontFamily: 'Plex', fontWeight: FontWeight.w700, fontSize: 14))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: kInk, minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7), side: const BorderSide(color: kBd), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)), textStyle: const TextStyle(fontFamily: 'Plex', fontWeight: FontWeight.w700))),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: kAc, foregroundColor: Colors.white),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBd)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBd))),
      chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)), side: const BorderSide(color: kBd), selectedColor: kAc, labelStyle: const TextStyle(fontFamily: 'Plex', fontWeight: FontWeight.w700)),
      dividerTheme: const DividerThemeData(color: Color(0xFFE5EAF0)),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: kNavy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), contentTextStyle: const TextStyle(fontFamily: 'Plex', color: Colors.white, fontWeight: FontWeight.w600)),
      dialogTheme: DialogTheme(backgroundColor: Colors.white, surfaceTintColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22)))),
      switchTheme: SwitchThemeData(thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null), trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? kAc : null)),
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
  const BCard({super.key, this.c = const Color(0xFF2563EB), this.title, required this.child, this.pad = const EdgeInsets.fromLTRB(12, 10, 12, 12), this.trailing});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: kNavy.withOpacity(.07), blurRadius: 18, offset: const Offset(0, 6), spreadRadius: -4), const BoxShadow(color: Color(0x0A0F2742), blurRadius: 2, offset: Offset(0, 1))]),
        child: ClipRRect(borderRadius: BorderRadius.circular(18), child: Container(
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.alphaBlend(c.withOpacity(.06), Colors.white), Colors.white], stops: const [0, .3]), border: Border.all(color: kBd, width: 1)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(height: 3, decoration: BoxDecoration(gradient: LinearGradient(colors: [c, c.withOpacity(.35)]))),
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
  /// لو موجود: الكارت بيتداس عليه ويفتح «الرقم ده جه منين» (🧮 زي القديم)
  final VoidCallback? onTap;
  const BStat(this.l, this.v, {super.key, this.sub, this.c, this.text, this.onTap});
  @override
  Widget build(BuildContext context) {
    final col = c ?? (v < 0 ? kRed : kOk);
    final w = Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Color.alphaBlend(col.withOpacity(.18), kBd)), boxShadow: [BoxShadow(color: kNavy.withOpacity(.06), blurRadius: 14, offset: const Offset(0, 5), spreadRadius: -4)]),
      child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Container(
        color: Color.alphaBlend(col.withOpacity(.05), Colors.white),
        child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 4, color: col),
          Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l, style: const TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(text != null ? (Priv.on ? '•••' : text!) : money(v), style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color.alphaBlend(Colors.black.withOpacity(.08), col))),
            if (sub != null) Text(sub!, style: const TextStyle(color: kMuted, fontSize: 11)),
            if (onTap != null) const Align(alignment: AlignmentDirectional.centerEnd, child: Text('🧮', style: TextStyle(fontSize: 15))),
          ]))),
        ])),
      )),
    );
    if (onTap == null) return w;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: w);
  }
}
