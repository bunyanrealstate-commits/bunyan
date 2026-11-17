import 'package:flutter/material.dart';
import '../core/auto.dart';
import '../core/model.dart';
import '../core/native.dart';
import '../core/store.dart';
import 'theme.dart';
import 'villas.dart';
import 'shots.dart';

/// 📥 أبديت الجروبات التلقائي: تختار جروبات الشركات، وكل جروب تبع أنهي شركة
class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});
  @override
  State<GroupsPage> createState() => _GroupsState();
}

class _GroupsState extends State<GroupsPage> with WidgetsBindingObserver {
  bool on = false, loading = true, tried = false, reading = false;
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
    final raw = (Store.I.cfg['groups'] as Map?) ?? {};
    if (raw.keys.any((k) => AutoUpd.cleanGroup('$k') != '$k')) { Store.I.cfg['groups'] = AutoUpd.groups; await Store.I.saveCfg(); await AutoUpd.sync(); }
    if (mounted) setState(() { on = o; seen = s; loading = false; });
  }

  Future<void> _perm() async {
    String r = 'fail';
    try { r = await Native.ch.invokeMethod<String>('notifPerm') ?? 'fail'; } catch (e) { r = 'fail'; }
    if (!mounted) return;
    setState(() => tried = true);
    if (r == 'fail') toast(context, '⚠️ الموبايل مفتحش الإعدادات — اتبع الخطوات اللي تحت');
  }

  Future<void> _save({bool read = true}) async {
    await Store.I.saveCfg();
    await AutoUpd.sync();
    try { await Native.ch.invokeMethod('perms'); } catch (_) {}
    if (mounted) setState(() {});
    if (read) _read();
  }

  /// يقرا صور الأبديت اللي وصلت قبل كده (آخر 3 أيام) من الجروبات المتابَعة
  Future<void> _read() async {
    if (reading) return;
    setState(() => reading = true);
    final r = await AutoUpd.pull();
    if (!mounted) return;
    setState(() => reading = false);
    if (r.isNotEmpty) toast(context, '📥 ${r.length} أبديت اتقرا — شوف «آخر التحديثات» تحت');
  }

  Future<void> _toggle(String g, bool b) async {
    g = AutoUpd.cleanGroup(g);
    if (AutoUpd.allOn) {
      final o = AutoUpd.off..remove(g);
      if (!b) o.add(g);
      Store.I.cfg['offGroups'] = o;
    } else {
      final m = Map<String, dynamic>.from(AutoUpd.groups);
      if (!b) { m.remove(g); } else { m[g] = AutoUpd.companyOf(g); }
      Store.I.cfg['groups'] = m;
    }
    await _save(read: b);
  }

  Future<void> _company(String g) async {
    final comps = {for (final v in Store.I.villas) if (str(v['company']).isNotEmpty) str(v['company'])}.toList()..sort();
    var c = await pickDlg(context, 'جروب «$g» تبع أنهي شركة؟', [for (final x in comps) [x, x], ['+', '✏️ اكتب اسم الشركة']], AutoUpd.companyOf(g));
    if (c == null || !mounted) return;
    if (c == '+') { final o = await formDlg(context, 'اسم الشركة', [FS('c', 'زي: الغانم', v: AutoUpd.companyOf(g))], ok: 'تمام'); if (o == null) return; c = o['c'] ?? g; }
    final m = Map<String, dynamic>.from(AutoUpd.groups)..[g] = c;
    Store.I.cfg['groups'] = m;
    await _save(read: false);
  }

  Future<void> _all(bool b) async {
    if (b && !await confirmDlg(context, 'كل الجروبات (حتى الجديدة) هتتقري صورها بـ Gemini علشان يلاقي الأبديت.\nالصور العادية بيتجاهلها، بس بتتبعت لـ Gemini يشوفها.\nأي جروب مش عايزه اقفله من القايمة.', ok: 'تابع الكل')) return;
    Store.I.cfg['allGroups'] = b;
    await _save(read: b);
  }

  @override
  Widget build(BuildContext context) {
    final sel = AutoUpd.groups;
    final names = {...seen.keys, ...sel.keys}.where((g) => q.isEmpty || g.toLowerCase().contains(q.toLowerCase())).toList()
      ..sort((a, b) { final x = AutoUpd.follows(a) ? 0 : 1, y = AutoUpd.follows(b) ? 0 : 1; if (x != y) return x - y; return ((seen[b]?['at'] ?? 0) as num).compareTo((seen[a]?['at'] ?? 0) as num); });
    final log = AutoUpd.log;
    return Scaffold(
      appBar: AppBar(title: const Text('📥 أبديت الجروبات')),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 40), children: [
        Card(color: on ? const Color(0xFFE6F6EC) : const Color(0xFFFFF4E0), child: ListTile(
          leading: Icon(on ? Icons.check_circle : Icons.notifications_active_outlined, color: on ? kOk : kGold),
          title: Text(on ? 'شغال — بيتابع جروبات الشركات' : 'خطوة واحدة: اسمح للتطبيق يشوف إشعارات الواتساب', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(on ? 'الأبديت بيتقري لوحده ويتحدث في الفلل. لازم إشعارات الجروب تكون شغالة (لو مكتوم الواتساب مبيبعتش إشعار — خليه صامت بدل الكتم)' : 'دوس هنا ← دوّر على «عروض الشقق» ← شغّله ← وارجع'),
          onTap: on ? null : _perm,
        )),
        if (!on && tried) Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('لو مالقيتش «عروض الشقق» أو الزرار رمادي ومش بيرضى يتشغل:', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('1) دوس الزرار تحت يفتحلك «معلومات التطبيق»\n2) دوس النقط الـ3 ⋮ فوق على الشمال\n3) اختار «السماح بالإعدادات المقيدة» (Allow restricted settings)\n4) ارجع هنا ودوس الكارت الأصفر تاني'),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: () async { try { await Native.ch.invokeMethod('appInfo'); } catch (_) {} }, icon: const Icon(Icons.info_outline), label: const Text('افتح معلومات التطبيق')),
        ]))),
        Card(color: const Color(0xFFE3F4F5), child: ListTile(leading: const Icon(Icons.photo_library_outlined, color: kAc), title: Text('📷 صور الأبديت اللي اتقرت (${AutoUpd.log.where((x) => str(x['img']).isNotEmpty).length})', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('شوف كل صورة لقطها وإيه اللي اتغير بسببها'), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShotsPage())))),
        Card(child: SwitchListTile(value: AutoUpd.allOn, onChanged: _all, title: const Text('تابع كل الجروبات', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('أي جروب يبعت صورة أبديت يتقري — حتى الجروبات الجديدة. اقفل اللي مش عايزه من تحت'))),
        Card(child: ListTile(leading: reading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Icon(Icons.refresh, color: kAc), title: Text(reading ? 'بيقرا الصور اللي وصلت…' : 'اقرا صور الأبديت اللي وصلت (آخر 3 أيام)', style: const TextStyle(fontWeight: FontWeight.w700)), onTap: reading ? null : _read)),
        const SizedBox(height: 8),
        const Text('علّم جروبات الشركات (بيظهر هنا أي جروب يجيلك منه رسالة):', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        TextField(decoration: const InputDecoration(labelText: 'دوّر على جروب', prefixIcon: Icon(Icons.search)), onChanged: (v) => setState(() => q = v)),
        if (loading) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
        if (q.trim().isNotEmpty && !names.any((g) => g.toLowerCase() == q.trim().toLowerCase()))
          Card(color: const Color(0xFFE3F4F5), child: ListTile(leading: const Icon(Icons.add_circle, color: kAc), title: Text('تابع جروب «${q.trim()}»', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('اكتب اسم الجروب زي ما هو مكتوب في الواتساب بالظبط'), onTap: () { Store.I.cfg['groups'] = {...AutoUpd.groups, AutoUpd.cleanGroup(q.trim()): AutoUpd.companyOf(q.trim())}; _save(); })),
        if (!loading && names.isEmpty) const Padding(padding: EdgeInsets.all(14), child: Text('الجروبات بتظهر هنا أول ما يجيلك منها رسالة جديدة (بعد ما شغّلت الإذن). أو اكتب اسم الجروب فوق ودوس «تابع».', style: TextStyle(color: kMuted))),
        for (final g in names)
          Card(child: SwitchListTile(
            value: AutoUpd.follows(g), onChanged: (b) => _toggle(g, b),
            title: Text(g, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text([if (AutoUpd.follows(g)) '🏢 ${AutoUpd.companyOf(g)} ✏️', if (((seen[g]?['img'] ?? 0) as num) > 0) '📷 ${seen[g]?['img']} صورة'].join(' • ')),
            secondary: AutoUpd.follows(g) ? IconButton(tooltip: 'غيّر الشركة', icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _company(g)) : null,
          )),
        if (log.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('آخر التحديثات:', style: TextStyle(fontWeight: FontWeight.w800)),
          for (final l in log.take(25))
            Card(child: ListTile(dense: true, title: Text(str(l['m'])), subtitle: Text('${str(l['g'])} • ${str(l['at']).replaceFirst('T', ' ').split('.').first}'), trailing: Store.I.villa(str(l['vid'])) == null ? null : const Icon(Icons.chevron_left), onTap: Store.I.villa(str(l['vid'])) == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => VillaPage(str(l['vid'])))))),
        ],
      ]),
    );
  }
}
