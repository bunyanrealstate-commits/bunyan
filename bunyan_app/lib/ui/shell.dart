import 'package:flutter/material.dart';
import 'i18n.dart';
import '../core/store.dart';
import '../core/js.dart';
import 'theme.dart';
import 'groups.dart';
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
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  @override
  void initState() {
    super.initState();
    Store.I.addListener(_r); Ws.I.addListener(_r);
    Native.init();
    Native.takeLink().then((ok) { if (!ok && Store.I.linked) Store.I.sync(); });
    Future.delayed(const Duration(seconds: 5), () => Updater.check());
    Future.delayed(const Duration(seconds: 3), () => Rem.schedule());
    WidgetsBinding.instance.addObserver(_life);
  }
  late final _life = _Life(() { Native.takeLink().then((ok) { if (!ok && Store.I.linked) Store.I.sync(); }); Updater.check().then((m) { if (m != null && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m))); }); });
  void _r() { if (mounted) setState(() {}); }
  @override
  void dispose() { Store.I.removeListener(_r); Ws.I.removeListener(_r); WidgetsBinding.instance.removeObserver(_life); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final st = Store.I;
    if (!st.loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!st.linked && lst(st.S['units']).isEmpty) return const LinkScreen();
    // مش const: لازم الصفحة تتبني من جديد لما المجموعة أو البيانات تتغير
    return Directionality(
      textDirection: Tr.dir,
      child: Scaffold(
        appBar: AppBar(
          title: Row(children: [
            const Text('BUNYAN', style: TextStyle(fontWeight: FontWeight.w900, color: kGreen, letterSpacing: 2)),
            const SizedBox(width: 10),
            Expanded(child: _groupPicker()),
          ]),
          actions: [
            IconButton(
              tooltip: Tr.t('مزامنة'),
              onPressed: st.syncing ? null : () async { final m = await st.sync(); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m))); },
              icon: st.syncing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.sync, color: st.cfg['dirty'] == true ? kTerra : kGreen),
            ),
          ],
        ),
        body: RefreshIndicator(onRefresh: () async { await st.sync(); }, child: ListenableBuilder(listenable: Listenable.merge([Store.I, Ws.I]), builder: (_, __) { final w = Ws.I.resolve(); return KeyedSubtree(key: ValueKey('$tab|$w|${Tr.lang}'), child: [const HomePage(), const UnitsPage(), const ExpensesPage(), const MorePage()][tab]); })),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Tr.t('الداشبورد')),
            NavigationDestination(icon: Icon(Icons.apartment_outlined), selectedIcon: Icon(Icons.apartment), label: Tr.t('الوحدات')),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: Tr.t('المصاريف')),
            NavigationDestination(icon: Icon(Icons.more_horiz), label: Tr.t('المزيد')),
          ],
        ),
      ),
    );
  }

  Widget _groupPicker() {
    final S = Store.I.S; final gs = objs(S['groups']);
    final noG = objs(S['units']).any((u) => !truthy(u['g']));
    if (gs.isEmpty && !noG) return const SizedBox();
    final cur = Ws.I.resolve();
    final items = <DropdownMenuItem<String>>[
      for (final g in gs) DropdownMenuItem(value: str(g['id']), child: Text('📂 ${str(g['name'])}', overflow: TextOverflow.ellipsis)),
      if (noG) DropdownMenuItem(value: '-', child: Text(Tr.t('📂 بدون مجموعة'))),
      DropdownMenuItem(value: '__m', child: Text(Tr.t('⚙ إدارة المجموعات'))),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(color: kSand, borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: items.any((x) => x.value == cur) ? cur : null, isExpanded: true, style: const TextStyle(fontSize: 14, color: kInk, fontWeight: FontWeight.w700, fontFamily: 'Plex'),
        items: items,
        onChanged: (v) {
          if (v == null) return;
          if (v == '__m') { Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GroupsPage())); return; }
          Ws.I.pick(v);
        },
      )),
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
