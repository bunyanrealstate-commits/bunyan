import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const kGreen = Color(0xFF1F7A55), kInk = Color(0xFF1D2733), kMuted = Color(0xFF7A6A55), kPaper = Color(0xFFF6F3EE), kSand = Color(0xFFF1EADB), kRed = Color(0xFFB3261E), kTerra = Color(0xFFC0623E);

ThemeData bunyanTheme() => ThemeData(
      useMaterial3: true,
      fontFamily: 'Plex',
      colorScheme: ColorScheme.fromSeed(seedColor: kGreen, primary: kGreen, surface: Colors.white),
      scaffoldBackgroundColor: kPaper,
      appBarTheme: const AppBarTheme(backgroundColor: kPaper, foregroundColor: kInk, elevation: 0, centerTitle: false),
      cardTheme: CardTheme(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFEDE6D8)))),
    );

final _nf = NumberFormat('#,##0', 'en');
/// زي $() في بنيان: رقم بالدرهم
String money(num v) { final r = v.isNaN ? 0 : v.round(); return '${r < 0 ? '-' : ''}${_nf.format(r.abs())}'; }
Color sign(num v) => v < 0 ? kRed : kGreen;
