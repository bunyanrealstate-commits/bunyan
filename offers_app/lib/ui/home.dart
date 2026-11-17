import 'package:flutter/material.dart';
import '../core/auto.dart';
import '../core/model.dart';
import '../core/reqs.dart';
import '../core/store.dart';
import '../core/suggest.dart';
import 'reqs.dart';
import 'settings.dart';
import 'shots.dart';
import 'suggest.dart';
import 'theme.dart';

/// 🏠 الرئيسية: كل اللي محتاجه النهارده في صفحة واحدة — مين تبعتله، وإيه اللي اتغير
class HomePage extends StatelessWidget {
  final void Function(int tab) go;
  const HomePage({super.key, required this.go});

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Store.I, builder: (context, _) {
        final un = Store.I.villas.expand((v) => objs(v['units'])).toList();
        final avail = un.where((u) => u['avail'] != false).length;
        final fresh = Reqs.newFor();
        final now = DateTime.now();
        final soon = Reqs.all.where((r) { final w = DateTime.tryParse(str(r['when'])); return Reqs.open(r) && w != null && w.difference(now).inDays <= 7 && w.difference(now).inDays >= -3; }).toList();
        final due = Reqs.all.where(Reqs.dueFollow).toList();
        bool today(Obj x) { final d = DateTime.tryParse(str(x['at'])); return d != null && d.year == now.year && d.month == now.month && d.day == now.day; }
        final ups = AutoUpd.log.where((x) => today(x) && x['same'] != true && !str(x['m']).startsWith('⏭️')).toList();
        final waiting = Reqs.all.where((r) => Reqs.open(r)).length;
        final sug = Sug.count();
        final deals = objs(Store.I.D['deals']);
        final dm = deals.where((d) { final t = DateTime.tryParse(str(d['at'])); return t != null && t.year == now.year && t.month == now.month; }).toList();
        return Scaffold(
          appBar: AppBar(title: const Text('🏡 عروض الشقق'), actions: [
            IconButton(tooltip: 'الإعدادات', icon: const Icon(Icons.settings_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()))),
          ]),
          body: ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 30), children: [
            // الأرقام المهمة
            Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Row(children: [
              _stat('$avail', 'شقة متاحة', kOk, () => go(1)),
              _stat('$waiting', 'عميل', kAc2, () => go(2)),
              _stat('${ups.length}', 'تغيير النهارده', kGold, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShotsPage()))),
            ]))),
            // 1) عملاء نزلتلهم شقق
            if (fresh.isNotEmpty) ...[
              const _H('🔔 نزلتلهم شقق جديدة — ابعتلهم'),
              for (final r in fresh.take(8)) _client(context, r, '${Reqs.fresh(r).length} شقة جديدة تناسبه'),
            ],
            // 2) هيسكنوا قريب
            if (soon.isNotEmpty) ...[
              const _H('📅 هيسكنوا قريب'),
              for (final r in soon.take(8)) _client(context, r, '${Reqs.matches(r).length} شقة تناسبه دلوقتي'),
            ],
            // 3) متابعة
            if (due.isNotEmpty) ...[
              const _H('↩️ محتاجين متابعة'),
              for (final r in due.take(8)) _client(context, r, 'بعتله من ${now.difference(DateTime.tryParse(str(r['sentAt'])) ?? now).inDays} يوم'),
            ],
            if (fresh.isEmpty && soon.isEmpty && due.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('✅ مفيش حد مستني رد دلوقتي.\nأول ما ينزل أبديت فيه شقة تناسب عميل، هيظهرلك هنا.', style: TextStyle(color: kMuted, height: 1.6)))),
            // 4) اللي اتغير النهارده
            const _H('📥 اللي اتغير النهارده'),
            if (ups.isEmpty) const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('مفيش تغيير لسه — الأبديت بيتقري لوحده من الجروبات', style: TextStyle(color: kMuted))),
            for (final x in ups.take(6)) Card(child: ListTile(dense: true, title: Text(str(x['m']), maxLines: 3, overflow: TextOverflow.ellipsis), subtitle: Text(str(x['g'])), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShotsPage())))),
            TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShotsPage())), icon: const Icon(Icons.chevron_left), label: const Text('كل الأبديت')),
            if (deals.isNotEmpty) Card(color: const Color(0xFFE6F6EC), child: ListTile(leading: const Icon(Icons.payments_outlined, color: kOk), title: Text('💰 الشهر ده: ${dm.length} صفقة • ${money(dm.fold<double>(0, (a, d) => a + numOf(d['comm'])))} درهم عمولة', style: const TextStyle(fontWeight: FontWeight.w800)))),
            if (sug > 0) Card(color: const Color(0xFFE3F4F5), child: ListTile(leading: const Icon(Icons.lightbulb_outline, color: kAc), title: Text('💡 $sug اقتراح (فيديوهات تتربط / لوكيشن)'), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SuggestPage())))),
          ]),
        );
      });

  Widget _stat(String n, String l, Color c, VoidCallback onTap) => Expanded(child: InkWell(onTap: onTap, child: Column(children: [Text(n, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: c)), Text(l, style: const TextStyle(fontSize: 12, color: kMuted))])));

  Widget _client(BuildContext context, Obj r, String sub) => Card(child: ListTile(
        leading: CircleAvatar(backgroundColor: const Color(0xFFD5EEF0), child: Text(reqName(r).characters.first, style: const TextStyle(fontWeight: FontWeight.w800, color: kInk))),
        title: Text(reqName(r), style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${reqSummary(r)}\n$sub', style: const TextStyle(fontSize: 12.5)),
        isThreeLine: true,
        trailing: const Icon(Icons.send, color: Color(0xFF25D366)),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReqPage(str(r['id'])))),
      ));
}

class _H extends StatelessWidget {
  final String t;
  const _H(this.t);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(4, 16, 4, 6), child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)));
}
