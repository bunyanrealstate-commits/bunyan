import 'package:flutter/material.dart';

const kAc = Color(0xFF0E7C86), kAc2 = Color(0xFF1473E6), kInk = Color(0xFF0F1B2D), kMuted = Color(0xFF5E6878), kBg = Color(0xFFF1F6F6), kBd = Color(0xFFD8DEE4), kOk = Color(0xFF15924A), kRed = Color(0xFFD93D42), kGold = Color(0xFFE8A33D);

ThemeData offersTheme() => ThemeData(
      useMaterial3: true, fontFamily: 'Plex',
      colorScheme: ColorScheme.fromSeed(seedColor: kAc, primary: kAc, surface: Colors.white),
      scaffoldBackgroundColor: kBg,
      appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: kInk, elevation: 0, scrolledUnderElevation: 1, surfaceTintColor: Colors.white, titleTextStyle: TextStyle(fontFamily: 'Plex', fontSize: 19, fontWeight: FontWeight.w700, color: kInk)),
      cardTheme: CardTheme(color: Colors.white, elevation: 0, margin: const EdgeInsets.symmetric(vertical: 5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE2E7EC)))),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBd)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBd))),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: kAc, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), textStyle: const TextStyle(fontFamily: 'Plex', fontWeight: FontWeight.w700, fontSize: 15))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: kInk, side: const BorderSide(color: kBd), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)), textStyle: const TextStyle(fontFamily: 'Plex', fontWeight: FontWeight.w700))),
      chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)), side: const BorderSide(color: kBd), selectedColor: kAc, labelStyle: const TextStyle(fontFamily: 'Plex', fontWeight: FontWeight.w700)),
      navigationBarTheme: const NavigationBarThemeData(backgroundColor: Colors.white, indicatorColor: Color(0xFFD5EEF0)),
    );

void toast(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

class FS { final String k, l; final dynamic v; final bool num, multi; const FS(this.k, this.l, {this.v, this.num = false, this.multi = false}); }

Future<Map<String, String>?> formDlg(BuildContext context, String title, List<FS> fs, {String ok = 'حفظ'}) {
  final c = {for (final f in fs) f.k: TextEditingController(text: f.v == null ? '' : '${f.v}')};
  return showDialog<Map<String, String>>(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final f in fs) Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: c[f.k], maxLines: f.multi ? 3 : 1, keyboardType: f.num ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, decoration: InputDecoration(labelText: f.l))),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, {for (final e in c.entries) e.key: e.value.text.trim()}), child: Text(ok))],
      )));
}

Future<String?> pickDlg(BuildContext context, String title, List<List<String>> opts, [String? cur]) => showDialog<String>(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: SimpleDialog(title: Text(title), children: [
      for (final o in opts) SimpleDialogOption(onPressed: () => Navigator.pop(ctx, o[0]), child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Icon(o[0] == cur ? Icons.radio_button_checked : Icons.radio_button_off, color: kAc, size: 20), const SizedBox(width: 10), Expanded(child: Text(o[1], style: const TextStyle(fontSize: 15)))]))),
    ])));

Future<bool> confirmDlg(BuildContext context, String msg, {String ok = 'تمام'}) async => await showDialog<bool>(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(content: Text(msg), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لأ')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok))]))) ?? false;
