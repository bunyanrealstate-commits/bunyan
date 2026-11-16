import 'package:flutter/material.dart';
import 'i18n.dart';
import '../core/store.dart';
import '../core/js.dart';
import 'theme.dart';
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
  String resolve() {
    final gs = objs(Store.I.S['groups']).map((g) => str(g['id'])).toList();
    if (value.isNotEmpty && (value == 'all' || value == '-' || gs.contains(value))) return value;
    return gs.isNotEmpty ? gs.first : 'all';
  }
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
    debugPrint('BNYDBG shell ws=${Ws.I.resolve()} v=${Ws.I.value}');
    final pages = <Widget>[HomePage(key: ValueKey('h${Ws.I.resolve()}')), UnitsPage(key: ValueKey('u${Ws.I.resolve()}')), ExpensesPage(key: ValueKey('e${Ws.I.resolve()}')), MorePage(key: ValueKey('m${Ws.I.resolve()}'))];
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
        body: RefreshIndicator(onRefresh: () async { await st.sync(); }, child: pages[tab]),
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
    final gs = objs(Store.I.S['groups']);
    if (gs.length < 2) return const SizedBox();
    final cur = Ws.I.resolve();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final g in gs)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: ChoiceChip(label: Text(str(g['name']), style: const TextStyle(fontSize: 12)), selected: cur == g['id'], onSelected: (_) { debugPrint('BNYDBG tap ${g['id']}'); Ws.I.value = str(g['id']); }),
          ),
      ]),
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
