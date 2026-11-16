// بيفتح كل صفحات التطبيق ببيانات تجريبية (من غير أسماء حقيقية) ويفشل لو أي صفحة وقعت
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bunyan/core/store.dart';
import 'package:bunyan/core/js.dart';
import 'package:bunyan/ui/shell.dart';
import 'package:bunyan/ui/home.dart';
import 'package:bunyan/ui/units.dart';
import 'package:bunyan/ui/expenses.dart';
import 'package:bunyan/ui/more.dart';
import 'package:bunyan/ui/accounts.dart';
import 'package:bunyan/ui/cheques.dart';
import 'package:bunyan/ui/forecast.dart';
import 'package:bunyan/ui/groups.dart';
import 'package:bunyan/ui/trash.dart';
import 'package:bunyan/ui/sim.dart';
import 'package:bunyan/ui/monitor.dart';
import 'package:bunyan/ui/ai.dart';
import 'package:bunyan/ui/lease_edit.dart';
import 'package:bunyan/ui/unit_edit.dart';
import 'package:bunyan/ui/i18n.dart';
import 'package:bunyan/ui/theme.dart';
import 'package:flutter/services.dart';

void main() {
  setUpAll(() async {
    final l = FontLoader('Plex')..addFont(rootBundle.load('fonts/PlexArabic-500.ttf'))..addFont(rootBundle.load('fonts/PlexArabic-700.ttf'));
    await l.load();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.I.initTest(jsonDecode(File('test/fixture.json').readAsStringSync()) as Map<String, dynamic>);
  });

  Future<void> show(WidgetTester t, Widget w, String name) async {
    t.view.physicalSize = const Size(1080, 2400); t.view.devicePixelRatio = 2.6;
    await t.pumpWidget(MaterialApp(theme: bunyanTheme(), home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: w))));
    await t.pump(const Duration(milliseconds: 300));
    final ex = t.takeException();
    expect(ex, isNull, reason: '$name: $ex');
  }

  for (final (lang, hide) in [('ar', false), ('en', false), ('ar', true)]) {
    testWidgets('كل الصفحات تفتح ($lang${hide ? ' + العين' : ''})', (t) async {
      Store.I.cfg['lang'] = lang; Store.I.cfg['hide'] = hide;
      final gs = [...objs(Store.I.S['groups']).map((g) => str(g['id']))];
      for (final g in gs) {
        Ws.I.value = g;
        await show(t, const HomePage(), 'home $g');
        await show(t, const UnitsPage(), 'units $g');
        await show(t, const ExpensesPage(), 'expenses $g');
        await show(t, const MorePage(), 'more $g');
        await show(t, const AccountsPage(), 'accounts $g');
        await show(t, const ChequesPage(), 'cheques $g');
        await show(t, const ForecastPage(), 'forecast $g');
      }
      await show(t, const GroupsPage(), 'groups');
      await show(t, const TrashPage(), 'trash');
      await show(t, const SimPage(), 'sim');
      await show(t, const MonitorPage(), 'monitor');
      await show(t, const AiPage(), 'ai');
      for (final u in objs(Store.I.S['units'])) {
        await show(t, UnitDetail(u), 'unit ${u['name']}');
        await show(t, UnitEdit(str(u['id'])), 'unitedit ${u['name']}');
        final ls = objs(u['leases']);
        for (var k = 0; k < ls.length; k++) { await show(t, LeaseEdit(u, k), 'lease ${u['name']} $k'); }
        await show(t, LeaseEdit(u, null), 'newlease ${u['name']}');
      }
      await show(t, const UnitEdit(null), 'new unit');
      expect(Tr.lang, lang);
    });
  }
}
