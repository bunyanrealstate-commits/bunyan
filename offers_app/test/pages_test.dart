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
import 'package:offers/ui/suggest.dart';
import 'package:offers/core/suggest.dart';
import 'package:offers/core/offerpage.dart';
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
    Store.I.D['log'] = <dynamic>[<String, dynamic>{'at': DateTime.now().toIso8601String(), 'g': 'MARASI', 'm': '📥 الغانم 25: اتحجزت: 7', 'img': '123', 'vid': 'v3'}];
    await show(t, const ShotsPage(), 'shots');
    await show(t, const ReqsPage(), 'reqs-empty');
    final r = Reqs.add(name: 'Ahmed', phone: '971501234567', text: 'need 1bhk monthly 3500');
    Reqs.add(name: 'محمد', phone: '971551112222', text: 'عايز غرفتين وصالة دفعة واحدة 75 الف');
    final g10 = objs(Store.I.villa('v3')!['units']).firstWhere((u) => u['no'] == '10');
    final imp = await t.runAsync(() => Reqs.importContacts([{'n': '2bhk 2bath 80000 Omar', 'p': '971509998877'}, {'n': 'Hkeem Uae', 'p': '971500000001'}]));
    expect(imp, 1);
    final om = Reqs.all.firstWhere((r) => r['p'] == '971509998877');
    expect(om['st'], 'wait'); expect(Reqs.fresh(om), isEmpty);
    g10['type'] = '2bk2b'; g10['p1'] = 79000;
    expect(Reqs.newFor().any((r) => r['id'] == om['id']), true);
    await show(t, const ReqsPage(), 'reqs');
    expect(find.textContaining('Ahmed'), findsOneWidget);
    await show(t, ReqPage(str(r['id'])), 'req');
    expect(find.textContaining('شقة تناسبه'), findsOneWidget);
    final g2 = objs(Store.I.villa('v3')!['units']).first..['newAt'] = DateTime.now().toIso8601String()..['videos'] = ['42'];
    expect(Sug.posts().length, 1);
    expect(Sug.caption(Store.I.villa('v3')!, g2), contains('AED 70,000 / year'));
    Store.I.D['locSug'] = <dynamic>[<String, dynamic>{'id': 'l1', 'g': 'Alghanim', 'url': 'https://maps.app.goo.gl/abc', 'txt': 'Villa 25 location https://maps.app.goo.gl/abc'}];
    expect(Sug.villaFor(Sug.locs.first)?['id'], 'v3');
    Store.I.villa('v3')!['loc'] = '';
    final al = await t.runAsync(() => Sug.autoLocs());
    expect(al!.length, 1);
    expect(Store.I.villa('v3')!['loc'], 'https://maps.app.goo.gl/abc');
    Store.I.cfg['myPhone'] = '971523501023';
    final h = await t.runAsync(() => OfferPage.html(Search.run(Store.I.villas, types: {'2bk2b'}, pay: '1').take(2).toList(), pay: '1', en: true, client: 'Ahmed'));
    expect(h, contains('AED 70,000 / year — 1 payment'));
    expect(h, contains('https://wa.me/971523501023?text='));
    Store.I.D['deals'] = [{'at': DateTime.now().toIso8601String(), 'n': 'Ahmed', 'unit': 'x', 'comm': 2500}];
    await show(t, const ReqsPage(), 'reqs-deals');
    expect(find.textContaining('2,500 درهم عمولة'), findsOneWidget);
    await show(t, const SuggestPage(tab: 1), 'sug-loc');
    await show(t, const SuggestPage(tab: 2), 'sug-post');
  });
  test('عينات أبديت حقيقية (Marasi / Platinum / NA Holding)', () {
    // ده شكل اللي Gemini بيرجّعه للصور دي
    AutoUpd.applyRows('MARASI PROPERTIES GROUP', [
      {'company': 'MARASI PROPERTIES', 'kind': 'list', 'no': '12', 'villa': 'Villa Al Naqib 58', 'area': 'Riyad City', 'type': '1bk', 'p1': 37000, 'p2': 38000, 'p3': 39000, 'mo': 3700, 'inArea': true, 'note': 'Extension on the left'},
      {'no': '4', 'villa': 'Villa Al Jazairi 26', 'area': 'Shamkha City', 'type': '2bk', 'floor': '1', 'p1': 65000, 'p2': 66000, 'p3': 67000, 'inArea': false},
      {'no': '3', 'villa': 'Villa Al Hilal 13', 'area': 'Shakhbout City', 'type': '1bk', 'p1': 52000, 'inArea': false},
      {'no': '9', 'villa': 'Al Mamari Compound 92', 'area': 'Shakhbout City', 'type': 'st', 'booked': true, 'inArea': false},
      {'no': '5', 'villa': 'Villa Al Baharna 49', 'area': 'MBZ City', 'type': '1bk', 'p1': 58000, 'inArea': false},
    ]);
    final naqib = Store.I.villas.firstWhere((v) => v['no'] == '58');
    expect(naqib['name'], 'Villa Al Naqib 58');
    expect(Price.text(objs(naqib['units']).first), contains('38,000 درهم على دفعتين'));
    expect(Store.I.villas.any((v) => ['26', '13', '92', '49'].contains(v['no'])), false);
    expect(AutoUpd.log.first['m'], contains('اتجاهلت 4 شقة'));
    // إعلان سعر جديد لشقة واحدة: الأرقام بالألف، وباقي الفيلا يفضل متاح
    (Store.I.D['villas'] as List).add({'id': 'b22', 'name': 'Al-Buraiki Villa 22', 'no': '22', 'company': 'Platinum Team', 'area': 'Riyadh City', 'units': <dynamic>[<String, dynamic>{'id': 'b5', 'no': '5', 'type': '1bk', 'p1': 45000, 'avail': true}]});
    AutoUpd.applyRows('Platinum Team Real Estate', [{'company': 'Platinum Team', 'kind': 'price', 'no': '6', 'villa': 'Al-Buraiki Villa 22', 'area': 'Riyadh City', 'type': '2bk', 'floor': 'G', 'p1': 58, 'p2': 60, 'p3': 62, 'inArea': true, 'note': 'with yard'}]);
    final b22 = Store.I.villas.firstWhere((v) => v['id'] == 'b22');
    expect(objs(b22['units']).firstWhere((u) => u['no'] == '6')['p1'], 58000.0);
    expect(objs(b22['units']).firstWhere((u) => u['no'] == '5')['avail'], true);
    // NA Holding: 4 فلل كل واحدة باسمها ورقمها
    AutoUpd.applyRows('NA Holding Real-Estate', [
      {'company': 'NA Holding', 'kind': 'list', 'no': '5', 'villa': 'Villa Al Hammadi 3 – No. 163', 'area': 'Madinat Al Riyad', 'type': '1bk', 'floor': '1', 'p1': 38000, 'p2': 40000, 'mo': 3900, 'inArea': true},
      {'no': '9', 'villa': 'Villa Al Alhami – No. 138', 'area': 'Madinat Al Riyad', 'type': '1bk', 'floor': 'G', 'p1': 48000, 'p2': 50000, 'inArea': true},
      {'no': '9', 'villa': 'Villa Al Dhaheri – No. 85', 'area': 'Madinat Al Riyad', 'type': '2bk2b', 'floor': 'G', 'p1': 62000, 'p2': 65000, 'inArea': true},
      {'no': '11', 'villa': 'Villa Al Hajeri – No. 7', 'area': 'Madinat Al Riyad', 'type': '1bk', 'floor': 'G', 'p1': 35000, 'p2': 37000, 'inArea': true},
    ]);
    for (final n in ['163', '138', '85', '7']) { expect(Store.I.villas.where((v) => v['no'] == n && str(v['area']) == 'Madinat Al Riyad').length, 1, reason: n); }
    expect(Search.run(Store.I.villas, types: {'1bk'}, pay: 'mo', budget: 4000).any((x) => (x['u'] as Obj)['no'] == '5'), true);
  });
  test('إحداثيات من لينك الخريطة', () {
    expect(Geo.parse('https://www.google.com/maps/place/x/@24.3511,54.6012,17z'), [24.3511, 54.6012]);
    expect(Geo.parse('https://maps.google.com/?q=24.30,54.60'), [24.30, 54.60]);
    expect(Geo.parse('🔗 24°20\'07.3"N 54°45\'17.5"E | https://maps.app.goo.gl/x'), [24.335361, 54.754861]);
    expect(villaNoOf('📍فيلا رقم ١١٢ مدينة الرياض 📍'), '112');
    expect(villaNoOf('🔗 24°19\'14.7"N 54°47\'24.8"E | https://maps.app.goo.gl/LM8 فيلا الهاملي حوض 29 رقم 138 Villa Alhamli Zone 29 No 138'), '138');
    expect(Geo.dist([24.3511, 54.6012], [24.3520, 54.6012]).round(), 100);
  });
  test('فهم طلب العميل', () {
    var p = parseRequest('السلام عليكم عايز غرفة وصالة شهري ميزانيتي 3500 في الشامخة', areas: ['الشامخة', 'مدينة الرياض']);
    expect(p['types'], containsAll(['1bk', '1bk2b']));
    expect(p['pay'], 'mo'); expect(p['budget'], 3500.0); expect(p['area'], 'الشامخة'); expect(p['isReq'], true);
    p = parseRequest('Hi, looking for 2 BHK 2 bath, 1 cheque, budget 75k');
    expect(p['types'], ['2bk2b']); expect(p['pay'], '1'); expect(p['budget'], 75000.0); expect(p['lang'], 'en');
    p = parseRequest('استديو ٢٥٠٠ في الشهر');
    expect(p['types'], ['st']); expect(p['budget'], 2500.0);
    var c = parseContactName('Studio Fur 3500 Suzanne')!;
    expect(c['types'], ['st']); expect(c['fur'], true); expect(c['budget'], 3500.0); expect(c['name'], 'Suzanne');
    c = parseContactName('1bhk empty 4000 Ali Hassan')!;
    expect(c['types'], containsAll(['1bk'])); expect(c['fur'], false); expect(c['name'], 'Ali Hassan');
    expect(parseContactName('Hkeem Uae'), isNull);
    expect(parseContactName('Studio Fur 4500 Khalifa')!['budget'], 4500.0);
    expect(parseContactName('Studio Riyad 30, 000')!['budget'], 30000.0);
    expect(parseContactName('Studio Or 1bhk 42max الاحواض الاولي')!['budget'], 42000.0);
    expect(parseContactName('Ahmed Studio Photography 24'), isNull);
    expect(parseContactName('Studio Ali'), isNull);
    c = parseContactName('Studio Fur 2800 December')!;
    expect(c['fur'], true); expect(c['budget'], 2800.0); expect(c['name'], ''); expect(str(c['when']).substring(5, 7), '12');
    c = parseContactName('1bhk 40 Alvin')!;
    expect(c['budget'], 40000.0); expect(c['name'], 'Alvin'); expect(c['pay'], '3');
    c = parseContactName('1bhk 40 يفضل 2 حمام')!;
    expect(c['types'], containsAll(['1bk', '1bk2b'])); expect(c['budget'], 40000.0); expect(c['name'], '');
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
    final multi = [
      {'company': 'Yellow Line', 'no': '2', 'type': '1bk', 'p1': 54000, 'villa': 'Shakhbot Villa 4', 'area': 'Shakhbot'},
      {'no': '2', 'type': 'st', 'p1': 37000, 'villa': 'Shakhbot Villa 37', 'area': 'Shakhbot'},
      {'no': '8', 'type': '1bk', 'p1': 52000, 'villa': 'MBZ Villa 119 Zone 34', 'area': 'MBZ'},
    ];
    expect(AutoUpd.groupRows(multi).length, 3);
    final outside = [{'no': '1', 'type': 'st', 'p1': 30000, 'villa': 'Shakhbot Villa 9', 'area': 'Shakhbot', 'inArea': false}, {'no': '3', 'type': 'st', 'p1': 31000, 'villa': 'Kathiri Villa 151', 'area': 'Madinat Riyad', 'inArea': true}];
    final n0 = Store.I.villas.length;
    AutoUpd.applyRows('Yellow Line Real Estate', outside);
    expect(Store.I.villas.length, n0 + 1);
    expect(Store.I.villas.any((v) => v['no'] == '9'), false);
    expect(AutoUpd.log.any((l) => str(l['m']).contains('اتجاهلت 1 شقة برا مدينة الرياض')), true);
    (Store.I.D['villas'] as List).removeWhere((v) => (v as Map)['no'] == '151');
    AutoUpd.applyRows('Yellow Line Real Estate', multi);
    final yl = Store.I.villas.where((v) => str(v['company']).contains('Yellow')).toList();
    expect(yl.length, 3);
    expect(yl.map((v) => v['no']).toSet(), {'4', '37', '119'});
    expect(yl.firstWhere((v) => v['no'] == '4')['name'], 'Shakhbot Villa 4');
    final nv = findVilla('Apex', {'villa': 'Villa 40'})!;
    expect(nv['no'], '40');
    expect(Store.I.villas.length, 7);
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
