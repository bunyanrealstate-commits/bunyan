import 'package:flutter/material.dart';
import '../core/store.dart';
import '../core/native.dart';
import '../core/auto.dart';
import 'theme.dart';
import 'search.dart';
import 'villas.dart';
import 'home.dart';
import 'reqs.dart';
import 'send.dart';
import '../core/reqs.dart';
import '../core/suggest.dart';
import '../core/model.dart';

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
    Store.I.keep = AutoUpd.keepVilla;
    _wake();
  }
  void _r() { if (mounted) setState(() {}); }
  Future<void> _wake() async {
    if (await Native.takeLink()) { if (Store.I.villas.isEmpty) await Store.I.restore(); await Store.I.backup(); if (mounted) toast(context, '✅ اتربط ببنيان — Gemini والباك أب شغالين'); }
    Native.check();
    String? go;
    try { go = await Native.ch.invokeMethod<String>('go'); } catch (_) {}
    if (go == 'reqs' && mounted) setState(() => tab = 2);
    var nr = await Reqs.pullDms();
    if (Store.I.cfg['ctImport'] == true) {
      try {
        final cs = await Native.contacts();
        // مرة واحدة: امسح كل العملاء اللي التطبيق ضافهم — يفضل اللي سجلتهم بإيدك + أسامي آخر 5 أيام بس
        if (Store.I.cfg['wipe5'] != true && cs.isNotEmpty) {
          Store.I.cfg['ctSince'] = '2026-11-12'; Store.I.cfg['prune1'] = true;
          ((Store.I.D['reqs'] as List?) ?? []).removeWhere((r) => (r as Map)['src'] != 'manual');
          Store.I.cfg['wipe5'] = true; await Store.I.saveCfg(); await Store.I.save();
        }
        if (Store.I.cfg['prune1'] != true && cs.any((c) => (c['u'] ?? '').isNotEmpty)) { await Reqs.pruneOld(cs); Store.I.cfg['prune1'] = true; await Store.I.saveCfg(); }
        nr += await Reqs.importContacts(cs);
      } catch (_) {}
    }
    await Sug.pullLocs();
    final r0 = await AutoUpd.pull();
    await AutoUpd.autoFix();
    final r = [...r0, ...await Sug.autoLocs()];
    final fresh = r.isEmpty ? <Obj>[] : Reqs.newFor();
    await Reqs.pushSummary();
    if (!mounted) return;
    if (nr > 0) toast(context, '📩 $nr عميل جديد اتضاف');
    if (r.isNotEmpty) {
      showDialog(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(
            title: Text('📥 ${r.length} أبديت جديد من الجروبات'),
            content: SingleChildScrollView(child: Text([...r, if (Sug.posts().isNotEmpty) '\n📣 ${Sug.posts().length} شقة جديدة جاهزة بوست انستجرام (الفلل ← 💡 اقتراحات)', if (fresh.isNotEmpty) '\n🔔 فيه شقق جديدة تناسب ${fresh.length} عميل: ${fresh.map((x) => str(x['n'])).take(5).join('، ')}'].join('\n\n'))),
            actions: [if (fresh.isNotEmpty) TextButton(onPressed: () { Navigator.pop(ctx); setState(() => tab = 0); }, child: const Text('شوف مين تبعتله')), FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('تمام'))])));
    }
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) { if (s == AppLifecycleState.resumed) _wake(); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); Store.I.removeListener(_r); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final pages = [HomePage(go: (i) => setState(() => tab = i)), const SearchPage(), const ReqsPage(), const VillasPage()];
    return Scaffold(
      body: SafeArea(child: Column(children: [
        ValueListenableBuilder<String?>(valueListenable: Native.upd, builder: (_, v, __) {
          if (v == null) return const SizedBox.shrink();
          final t = {'perm': '⬆️ فيه نسخة جديدة — دوس ووافق مرة واحدة على «السماح من هذا المصدر»', 'dl': '⏳ بنزّل النسخة الجديدة…', 'inst': '⬆️ وافق على التحديث لو طلب منك', 'new': '⬆️ فيه نسخة جديدة — دوس تتحدث'}[v] ?? '';
          return Material(color: v == 'perm' ? kGold : kAc2, child: InkWell(onTap: () { if (v == 'perm') { Native.askPerm(); } else if (v == 'new') { Native.check(force: true); } }, child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [Expanded(child: Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))]))));
        }),
        Expanded(child: IndexedStack(index: tab, children: pages)),
        const SendBar(),
      ])),
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
        NavigationDestination(icon: Icon(Icons.manage_search), label: 'دوّر لعميل'),
        NavigationDestination(icon: Icon(Icons.people_alt_outlined), label: 'العملاء'),
        NavigationDestination(icon: Icon(Icons.villa_outlined), label: 'الفلل'),
      ]),
    );
  }
}
