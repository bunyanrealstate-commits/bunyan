import 'package:flutter/material.dart';
import '../core/auto.dart';
import '../core/model.dart';
import '../core/native.dart';
import '../core/store.dart';
import 'theme.dart';

/// 📥 أبديت الجروبات التلقائي: تختار جروبات الشركات، وكل جروب تبع أنهي شركة
class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});
  @override
  State<GroupsPage> createState() => _GroupsState();
}

class _GroupsState extends State<GroupsPage> with WidgetsBindingObserver {
  bool on = false, loading = true;
  Map<String, Map> seen = {};
  String q = '';

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _load(); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) { if (s == AppLifecycleState.resumed) _load(); }

  Future<void> _load() async {
    final o = await AutoUpd.on(), s = await AutoUpd.seen();
    if (mounted) setState(() { on = o; seen = s; loading = false; });
  }

  Future<void> _toggle(String g, bool b) async {
    final m = Map<String, dynamic>.from((Store.I.cfg['groups'] as Map?) ?? {});
    if (!b) { m.remove(g); } else {
      final comps = {for (final v in Store.I.villas) if (str(v['company']).isNotEmpty) str(v['company'])}.toList()..sort();
      var c = await pickDlg(context, 'جروب «$g» تبع أنهي شركة؟', [for (final x in comps) [x, x], ['+', '➕ شركة جديدة']]);
      if (c == null || !mounted) return;
      if (c == '+') { final o = await formDlg(context, 'اسم الشركة', [FS('c', 'زي: الغانم', v: g)], ok: 'تمام'); if (o == null) return; c = o['c'] ?? g; }
      m[g] = c;
    }
    Store.I.cfg['groups'] = m;
    await Store.I.saveCfg();
    await AutoUpd.sync();
    try { await Native.ch.invokeMethod('perms'); } catch (_) {}
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final sel = AutoUpd.groups;
    final names = {...seen.keys, ...sel.keys}.where((g) => q.isEmpty || g.toLowerCase().contains(q.toLowerCase())).toList()
      ..sort((a, b) { final x = sel.containsKey(a) ? 0 : 1, y = sel.containsKey(b) ? 0 : 1; if (x != y) return x - y; return ((seen[b]?['at'] ?? 0) as num).compareTo((seen[a]?['at'] ?? 0) as num); });
    final log = AutoUpd.log;
    return Scaffold(
      appBar: AppBar(title: const Text('📥 أبديت الجروبات')),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 40), children: [
        Card(color: on ? const Color(0xFFE6F6EC) : const Color(0xFFFFF4E0), child: ListTile(
          leading: Icon(on ? Icons.check_circle : Icons.notifications_active_outlined, color: on ? kOk : kGold),
          title: Text(on ? 'شغال — بيتابع جروبات الشركات' : 'خطوة واحدة: اسمح للتطبيق يشوف إشعارات الواتساب', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(on ? 'الأبديت بيتقري لوحده ويتحدث في الفلل. لازم إشعارات الجروب تكون شغالة (لو مكتوم الواتساب مبيبعتش إشعار — خليه صامت بدل الكتم)' : 'دوس هنا ← دوّر على «عروض الشقق» ← شغّله ← وارجع'),
          onTap: on ? null : () async { await Native.ch.invokeMethod('notifPerm'); },
        )),
        const SizedBox(height: 8),
        const Text('علّم جروبات الشركات (بيظهر هنا أي جروب يجيلك منه رسالة):', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        TextField(decoration: const InputDecoration(labelText: 'دوّر على جروب', prefixIcon: Icon(Icons.search)), onChanged: (v) => setState(() => q = v)),
        if (loading) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
        if (!loading && names.isEmpty) const Padding(padding: EdgeInsets.all(14), child: Text('لسه مفيش جروبات — أول ما يجيلك رسالة من جروب هيظهر هنا', style: TextStyle(color: kMuted))),
        for (final g in names)
          Card(child: SwitchListTile(
            value: sel.containsKey(g), onChanged: (b) => _toggle(g, b),
            title: Text(g, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text([if (sel.containsKey(g)) '🏢 ${sel[g]}', if (((seen[g]?['img'] ?? 0) as num) > 0) '📷 ${seen[g]?['img']} صورة'].join(' • ')),
          )),
        if (log.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('آخر التحديثات:', style: TextStyle(fontWeight: FontWeight.w800)),
          for (final l in log.take(25))
            Card(child: ListTile(dense: true, title: Text(str(l['m'])), subtitle: Text('${str(l['g'])} • ${str(l['at']).replaceFirst('T', ' ').split('.').first}'))),
        ],
      ]),
    );
  }
}
