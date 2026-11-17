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
import 'package:offers/ui/shots.dart';
import 'package:offers/ui/reqs.dart';
import 'package:offers/core/reqs.dart';
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
    Store.I.D['log'] = [{'at': DateTime.now().toIso8601String(), 'g': 'MARASI', 'm': '📥 الغانم 25: اتحجزت: 7', 'img': '123', 'vid': 'v3'}];
    await show(t, const ShotsPage(), 'shots');
    await show(t, const ReqsPage(), 'reqs-empty');
    final r = Reqs.add(name: 'Ahmed', phone: '971501234567', text: 'need 1bhk monthly 3500');
    Reqs.add(name: 'محمد', phone: '971551112222', text: 'عايز غرفتين وصالة دفعة واحدة 75 الف');
    await show(t, const ReqsPage(), 'reqs');
    expect(find.textContaining('Ahmed'), findsOneWidget);
    await show(t, ReqPage(str(r['id'])), 'req');
    expect(find.textContaining('شقة تناسبه'), findsOneWidget);
  });
  test('فهم طلب العميل', () {
    var p = parseRequest('السلام عليكم عايز غرفة وصالة شهري ميزانيتي 3500 في الشامخة', areas: ['الشامخة', 'مدينة الرياض']);
    expect(p['types'], containsAll(['1bk', '1bk2b']));
    expect(p['pay'], 'mo'); expect(p['budget'], 3500.0); expect(p['area'], 'الشامخة'); expect(p['isReq'], true);
    p = parseRequest('Hi, looking for 2 BHK 2 bath, 1 cheque, budget 75k');
    expect(p['types'], ['2bk2b']); expect(p['pay'], '1'); expect(p['budget'], 75000.0); expect(p['lang'], 'en');
    p = parseRequest('استديو ٢٥٠٠ في الشهر');
    expect(p['types'], ['st']); expect(p['budget'], 2500.0);
    p = parseRequest('call me 0501234567');
    expect(p['isReq'], false);
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
