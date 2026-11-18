import 'package:flutter/material.dart';
import 'i18n.dart';
import '../core/store.dart';
import '../core/js.dart';
import 'theme.dart';
import 'groups.dart';
import 'accounts.dart';
import 'eye.dart';
import 'dash.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'home.dart';
import 'units.dart';
import 'link.dart';
import 'more.dart';
import 'expenses.dart';
import '../core/native.dart';
import '../core/updater.dart';
import '../core/reminders.dart';

/// المجموعة المختارة (زي WS في بنيان القديم)
class Ws extends ValueNotifier<String> {
  static final Ws I = Ws._();
  Ws._() : super('');
  /// نفس wsBar في القديم: لو مفيش اختيار، المجموعة اللي فيها أكتر استديوهات — والاختيار بيتحفظ
  String resolve() {
    final S = Store.I.S; final gs = objs(S['groups']).map((g) => str(g['id'])).toList();
    final v = value.isNotEmpty ? value : str(Store.I.cfg['ws']);
    if (v.isNotEmpty && (v == '-' || gs.contains(v))) return v;
    if (gs.isEmpty) return objs(S['units']).isEmpty ? 'all' : '-';
    final us = objs(S['units']); final srt = [...gs]..sort((a, b) => us.where((u) => u['g'] == b).length.compareTo(us.where((u) => u['g'] == a).length));
    return srt.first;
  }
  void pick(String id) { value = id; Store.I.cfg['ws'] = id; Store.I.saveCfg(); }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  /// التاب المفتوح — أي صفحة تقدر تنقل لتاب تاني (مثلاً مربعات الحالة في الداشبورد ← الاستديوهات)
  static final tabN = ValueNotifier<int>(0);
  static void go(int i) => tabN.value = i;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int get tab => Shell.tabN.value;
  set tab(int v) => Shell.tabN.value = v;
  @override
  void initState() {
    super.initState();
    Store.I.addListener(_r); Ws.I.addListener(_r); Shell.tabN.addListener(_r);
    Native.init();
    Native.takeLink().then((ok) { if (!ok && Store.I.linked) Store.I.sync(); });
    Future.delayed(const Duration(seconds: 5), () => Updater.check());
    Future.delayed(const Duration(seconds: 3), () => Rem.schedule());
    WidgetsBinding.instance.addObserver(_life);
  }
  late final _life = _Life(() { Native.takeLink().then((ok) { if (!ok && Store.I.linked) Store.I.sync(); }); Updater.check(force: Updater.needPerm || Updater.state.value != null).then((m) { if (m != null && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m))); }); });
  void _r() { if (mounted) setState(() {}); }
  @override
  void dispose() { Store.I.removeListener(_r); Ws.I.removeListener(_r); Shell.tabN.removeListener(_r); WidgetsBinding.instance.removeObserver(_life); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final st = Store.I;
    if (!st.loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!st.linked && lst(st.S['units']).isEmpty) return const LinkScreen();
    // مش const: لازم الصفحة تتبني من جديد لما المجموعة أو البيانات تتغير
    final tabs = [
      [Icons.home_outlined, Tr.t('الداشبورد')], [Icons.apartment_outlined, Tr.t('الاستديوهات')], [Icons.bar_chart, Tr.t('الحسابات')],
      [Icons.receipt_long_outlined, Tr.t('المصاريف')], [Icons.groups_outlined, Tr.t('المجموعات')], [Icons.menu, Tr.t('المزيد')],
    ];
    return Directionality(
      textDirection: Tr.dir,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 62,
          titleSpacing: 10,
          // الهيدر زي القديم: اللوجو • العين • المجموعة • الساعة • الجرس • المزامنة
          title: Row(children: [
            Column(mainAxisSize: MainAxisSize.min, children: [SvgPicture.asset('assets/logo.svg', height: 21), const Text('Furnished', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF1D4B66), letterSpacing: 1.4, height: 1.2))]),
            EyeBtn(key: ValueKey('eye${Priv.on}')),
            const SizedBox(width: 8),
            const Expanded(child: GroupPill()),
            const SizedBox(width: 8),
            const HdClock(), const SizedBox(width: 8),
            const BellBtn(),
            SizedBox(width: 36, child: IconButton(
              padding: EdgeInsets.zero, tooltip: Tr.t('مزامنة'),
              onPressed: st.syncing ? null : () async { final m = await st.sync(); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m))); },
              icon: st.syncing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.sync, color: st.cfg['dirty'] == true ? kTerra : kAc),
            )),
          ]),
          bottom: PreferredSize(preferredSize: const Size.fromHeight(46), child: Container(
            decoration: const BoxDecoration(color: Color(0xF5FFFFFF), border: Border(bottom: BorderSide(color: Color(0xFF8D97A8), width: .6))),
            child: SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 6), child: Row(children: [
              for (var i = 0; i < tabs.length; i++) InkWell(
                onTap: () => setState(() => tab = i),
                child: Container(
                  height: 46, padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tab == i ? kAcD : Colors.transparent, width: 3))),
                  child: Row(children: [
                    Icon(tabs[i][0] as IconData, size: 18, color: tab == i ? kAcD : const Color(0xFF454852)),
                    const SizedBox(width: 6),
                    Text(tabs[i][1] as String, style: TextStyle(fontSize: 14, fontWeight: tab == i ? FontWeight.w800 : FontWeight.w600, color: tab == i ? kAcD : const Color(0xFF454852))),
                  ]),
                ),
              ),
            ])),
          )),
        ),
        body: RefreshIndicator(onRefresh: () async { await st.sync(); }, child: ListenableBuilder(listenable: Listenable.merge([Store.I, Ws.I]), builder: (_, __) {
          final w = Ws.I.resolve();
          final page = [const HomePage(), const UnitsPage(), const AccountsPage(inTab: true), const ExpensesPage(), const GroupsPage(inTab: true), const MorePage()][tab];
          return Column(children: [
            const _UpdBar(),
            Expanded(child: KeyedSubtree(key: ValueKey('$tab|$w|${Tr.lang}|${Priv.on}'), child: page)),
          ]);
        })),
      ),
    );
  }
}

class _Life extends WidgetsBindingObserver {
  final VoidCallback onResume;
  DateTime _last = DateTime(2000);
  _Life(this.onResume);
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed && DateTime.now().difference(_last).inSeconds > 20) { _last = DateTime.now(); onResume(); }
  }
}

/// شريط التحديث: بيظهر لو فيه نسخة جديدة (ومحتاجة إذن مرة واحدة أو بتتنزّل)
class _UpdBar extends StatelessWidget {
  const _UpdBar();
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String?>(valueListenable: Updater.state, builder: (_, v, __) {
        if (v == null) return const SizedBox.shrink();
        final t = {'perm': Tr.t('⬆️ فيه نسخة جديدة — دوس هنا ووافق مرة واحدة على «السماح من هذا المصدر» وارجع'), 'dl': Tr.t('⏳ بنزّل النسخة الجديدة…'), 'inst': Tr.t('⬆️ وافق على التحديث لو طلب منك'), 'new': Tr.t('⬆️ فيه نسخة جديدة — دوس هنا تتحدث')}[v] ?? '';
        return Material(color: v == 'perm' ? kTerra : kAc, child: InkWell(
          onTap: () async { if (v == 'perm') { await Updater.askPerm(); } else if (v == 'new') { await Updater.check(force: true); } },
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Row(children: [
            Expanded(child: Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
            if (v == 'perm' || v == 'new') const Icon(Icons.chevron_left, color: Colors.white),
          ])),
        ));
      });
}
