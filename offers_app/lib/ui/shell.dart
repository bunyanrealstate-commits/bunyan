import 'package:flutter/material.dart';
import '../core/store.dart';
import '../core/native.dart';
import '../core/auto.dart';
import 'theme.dart';
import 'search.dart';
import 'villas.dart';
import 'settings.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int tab = 0;
  @override
  void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this);
    Store.I.addListener(_r);
    _wake();
  }
  void _r() { if (mounted) setState(() {}); }
  Future<void> _wake() async {
    if (await Native.takeLink()) { if (Store.I.villas.isEmpty) await Store.I.restore(); await Store.I.backup(); if (mounted) toast(context, '✅ اتربط ببنيان — Gemini والباك أب شغالين'); }
    Native.check();
    final r = await AutoUpd.pull();
    if (r.isNotEmpty && mounted) {
      showDialog(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(title: Text('📥 ${r.length} أبديت جديد من الجروبات'), content: SingleChildScrollView(child: Text(r.join('\n\n'))), actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('تمام'))])));
    }
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) { if (s == AppLifecycleState.resumed) _wake(); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); Store.I.removeListener(_r); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final pages = [const SearchPage(), const VillasPage(), const SettingsPage()];
    return Scaffold(
      body: SafeArea(child: Column(children: [
        ValueListenableBuilder<String?>(valueListenable: Native.upd, builder: (_, v, __) {
          if (v == null) return const SizedBox.shrink();
          final t = {'perm': '⬆️ فيه نسخة جديدة — دوس ووافق مرة واحدة على «السماح من هذا المصدر»', 'dl': '⏳ بنزّل النسخة الجديدة…', 'inst': '⬆️ وافق على التحديث لو طلب منك', 'new': '⬆️ فيه نسخة جديدة — دوس تتحدث'}[v] ?? '';
          return Material(color: v == 'perm' ? kGold : kAc2, child: InkWell(onTap: () { if (v == 'perm') { Native.askPerm(); } else if (v == 'new') { Native.check(force: true); } }, child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [Expanded(child: Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))]))));
        }),
        Expanded(child: IndexedStack(index: tab, children: pages)),
      ])),
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: const [
        NavigationDestination(icon: Icon(Icons.manage_search), label: 'دوّر للعميل'),
        NavigationDestination(icon: Icon(Icons.villa_outlined), label: 'الفلل'),
        NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'الإعدادات'),
      ]),
    );
  }
}
