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
import 'package:offers/ui/groups.dart';
import 'package:offers/core/auto.dart';
import 'package:offers/core/model.dart';
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
    await show(t, const GroupsPage(), 'groups');
  });
  test('أبديت الجروب: يلاقي فيلا الغانم 25 ويحدثها', () {
    final meta = {'villa': 'RD 66 , VILLA 25', 'company': 'ALGHANIM REAL ESTATE', 'no': '2', 'type': '2bk2b', 'p1': 72000};
    final v = findVilla('Alghanim', meta)!;
    expect(v['id'], 'v3');
    final r = applyUpdate(v, [meta, {'no': '10', 'type': '3bk', 'p1': 90000}, {'no': '12', 'type': 'st', 'p1': 30000}]);
    expect(r, contains('اتحجزت: 7'));
    expect(r, contains('جديدة: 12'));
    expect(r, contains('2: 70,000→72,000'));
    expect(applyUpdate(v, [meta, {'no': '10', 'type': '3bk', 'p1': 90000}, {'no': '12', 'type': 'st', 'p1': 30000}], auto: true), 'مفيش تغيير');
    final few = applyUpdate(v, [{'no': '12', 'type': 'st', 'p1': 30000}], auto: true);
    expect(few, contains('معلّمتهمش'));
    expect(objs(v['units']).where((u) => u['avail'] != false).length, 3);
    final nv = findVilla('Apex', {'villa': 'Villa 40'})!;
    expect(nv['no'], '40');
    expect(Store.I.villas.length, 4);
    expect(villaNoOf('فيلا رقم 7'), '7');
    expect(AutoUpd.cleanGroup('MARASI PROPERTIES  GROUP (رسالتان)'), 'MARASI PROPERTIES GROUP');
    expect(AutoUpd.cleanGroup('\u200fModren Look Real Estate 🏡 (3 رسائل)'), 'Modren Look Real Estate 🏡');
    expect(AutoUpd.cleanGroup('Master Leader (5 messages)'), 'Master Leader');
    expect(AutoUpd.cleanGroup('Global Egyptian  3m'), 'Global Egyptian 3m');
    expect(AutoUpd.companyOf('Modren Look Real Estate 🏡 (رسالتان)'), 'Modren Look Real Estate');
    Store.I.cfg['allGroups'] = true; Store.I.cfg['offGroups'] = ['Family'];
    expect(AutoUpd.follows('MARASI PROPERTIES  GROUP'), true);
    expect(AutoUpd.follows('Family (3 رسائل)'), false);
  });
}
