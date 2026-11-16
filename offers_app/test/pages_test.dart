import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:offers/core/store.dart';
import 'package:offers/ui/theme.dart';
import 'package:offers/ui/search.dart';
import 'package:offers/ui/villas.dart';
import 'package:offers/ui/import.dart';
import 'package:offers/ui/settings.dart';
import 'fixture.dart';

void main() {
  setUpAll(() async { final l = FontLoader('Plex')..addFont(rootBundle.load('fonts/PlexArabic-500.ttf'))..addFont(rootBundle.load('fonts/PlexArabic-700.ttf')); await l.load(); });
  setUp(() async { SharedPreferences.setMockInitialValues({}); await Store.I.initTest((jsonDecode(jsonEncode(fixture)) as Map).cast<String, dynamic>()); });
  Future<void> show(WidgetTester t, Widget w, String n) async {
    t.view.physicalSize = const Size(1080, 2400); t.view.devicePixelRatio = 2.6;
    await t.pumpWidget(MaterialApp(theme: offersTheme(), home: Directionality(textDirection: TextDirection.rtl, child: w)));
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull, reason: n);
  }
  testWidgets('كل الصفحات تفتح', (t) async {
    await show(t, const SearchPage(), 'search');
    await t.enterText(find.byType(TextField).first, '3500'); await t.pump();
    expect(find.textContaining('شقة متاحة'), findsOneWidget);
    await show(t, const VillasPage(), 'villas');
    await show(t, const VillaPage('v1'), 'villa');
    await show(t, const ImportPage('v1'), 'import');
    await show(t, const SettingsPage(), 'settings');
  });
}
