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
  bool on = false, loading = true, tried = false, reading = false, files = true;
  Map<String, Map> seen = {};
  List<Map> dbg = [];
  String q = '';

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _load(); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) { if (s == AppLifecycleState.resumed) _load(); }

  Future<void> _load() async {
    final o = await AutoUpd.on(), s = await AutoUpd.seen();
    dbg = await AutoUpd.dbg();
    try { files = await Native.ch.invokeMethod<bool>('allFiles') ?? true; } catch (_) {}
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
    final m = Map<String, dynamic>.from(AutoUpd.groups);
    if (!b) { m.remove(g); } else { m[g] = AutoUpd.companyOf(g); }
    Store.I.cfg['groups'] = m;
    await _save(read: b);
  }

  Widget _row(String g) {
    final f = AutoUpd.follows(g), c = AutoUpd.companyOf(g), n = ((seen[g]?['img'] ?? 0) as num);
    final sub = [if (f && c.toLowerCase() != g.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}\s&.-]', unicode: true), '').trim()) '🏢 $c', if (n > 0) '📷 $n صورة'].join(' • ');
    return Card(child: ListTile(
      contentPadding: const EdgeInsetsDirectional.only(start: 14, end: 4),
      title: Text(g, style: TextStyle(fontWeight: FontWeight.w700, color: f ? kInk : kMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: sub.isEmpty ? null : Text(sub, style: const TextStyle(fontSize: 12.5)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (f) IconButton(tooltip: 'غيّر اسم الشركة', icon: const Icon(Icons.edit_outlined, size: 19, color: kMuted), onPressed: () => _company(g)),
        Switch(value: f, onChanged: (b) => _toggle(g, b)),
      ]),
    ));
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


  @override
  Widget build(BuildContext context) {
    final sel = AutoUpd.groups;
    final names = {...seen.keys, ...sel.keys}.toList()..sort((a, b) => ((seen[b]?['at'] ?? 0) as num).compareTo((seen[a]?['at'] ?? 0) as num));
    final act = names.where(AutoUpd.follows).toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final rest = names.where((g) => !AutoUpd.follows(g) && (q.isEmpty || g.toLowerCase().contains(q.toLowerCase()))).toList();
    final log = AutoUpd.log;
    return Scaffold(
      appBar: AppBar(title: const Text('📥 أبديت الجروبات')),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 40), children: [
        Card(color: on ? const Color(0xFFE6F6EC) : const Color(0xFFFFF4E0), child: ListTile(
          leading: Icon(on ? Icons.check_circle : Icons.notifications_active_outlined, color: on ? kOk : kGold),
          title: Text(on ? 'شغال ✅' : 'خطوة واحدة: اسمح للتطبيق يشوف إشعارات الواتساب', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(on ? 'الأبديت بيتقري لوحده من الشركات المفعّلة بس. خلي إشعارات الجروبات شغالة (صامت مش مكتوم)' : 'دوس هنا ← دوّر على «عروض الشقق» ← شغّله ← وارجع'),
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
        if (on && !files) Card(color: const Color(0xFFFFF4E0), child: ListTile(leading: const Icon(Icons.picture_as_pdf_outlined, color: kRed), title: const Text('📄 علشان يقرا أبديت الـ PDF', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('دوس هنا ← شغّل «السماح بإدارة كل الملفات» لـ «عروض الشقق» ← وارجع. ده علشان يفتح ملفات الـ PDF اللي بتنزل في الواتساب.'), onTap: () async { try { await Native.ch.invokeMethod('allFilesPerm'); } catch (_) {} })),
        Card(child: SwitchListTile(value: AutoUpd.onlyArea, onChanged: (b) async { Store.I.cfg['onlyArea'] = b; await _save(read: false); },
          title: Text('🏙️ الفلل اللي في ${str(Store.I.cfg['areas']).isEmpty ? 'مدينة الرياض' : str(Store.I.cfg['areas'])} بس', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('أي فيلا مكتوب في الأبديت إنها في منطقة تانية بيتجاهلها'),
          secondary: IconButton(tooltip: 'غيّر المناطق', icon: const Icon(Icons.edit_location_alt_outlined), onPressed: () async {
            final o = await formDlg(context, 'المناطق اللي تهمك', [FS('a', 'زي: مدينة الرياض، الشامخة', v: str(Store.I.cfg['areas']).isEmpty ? 'مدينة الرياض' : str(Store.I.cfg['areas']))]);
            if (o == null) return; Store.I.cfg['areas'] = o['a'] ?? ''; await _save(read: false);
          }))),
        Card(child: ListTile(leading: reading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Icon(Icons.refresh, color: kAc), title: Text(reading ? 'بيقرا الصور اللي وصلت…' : 'اقرا صور الأبديت اللي وصلت (آخر 3 أيام)', style: const TextStyle(fontWeight: FontWeight.w700)), onTap: reading ? null : _read)),
        Padding(padding: const EdgeInsets.fromLTRB(4, 16, 4, 6), child: Text('✅ الشركات المفعّلة (${act.length}) — الأبديت بيتقري منها بس', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5))),
        if (act.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('لسه مفيش — فعّل جروبات الشركات من تحت', style: TextStyle(color: kMuted))),
        for (final g in act) _row(g),
        const SizedBox(height: 10),
        TextField(decoration: const InputDecoration(labelText: 'دوّر على جروب تفعّله', prefixIcon: Icon(Icons.search), isDense: true), onChanged: (v) => setState(() => q = v)),
        if (loading) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
        if (q.trim().isNotEmpty && !names.any((g) => g.toLowerCase() == q.trim().toLowerCase()))
          Card(color: const Color(0xFFE3F4F5), child: ListTile(leading: const Icon(Icons.add_circle, color: kAc), title: Text('فعّل جروب «${q.trim()}»', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('اكتب اسم الجروب زي ما هو مكتوب في الواتساب بالظبط'), onTap: () { Store.I.cfg['groups'] = {...AutoUpd.groups, AutoUpd.cleanGroup(q.trim()): AutoUpd.companyOf(q.trim())}; _save(); })),
        if (rest.isNotEmpty) ExpansionTile(key: ValueKey('rest${q.isNotEmpty}'), initiallyExpanded: q.trim().isNotEmpty, tilePadding: const EdgeInsets.symmetric(horizontal: 4),
          title: Text('⚪ جروبات مش مفعّلة (${rest.length}) — متجاهَلة', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('فعّل أي جروب شركة عايزه يتقري'),
          children: [for (final g in rest.take(150)) _row(g)]),
        const SizedBox(height: 8),
        ExpansionTile(tilePadding: const EdgeInsets.symmetric(horizontal: 4), title: const Text('🔎 تفاصيل (حصل إيه لكل صورة)', style: TextStyle(color: kMuted)), children: [
        if (dbg.isNotEmpty) ...[
          const Text('🔎 آخر صور الجروبات حصلها إيه:', style: TextStyle(fontWeight: FontWeight.w800)),
          for (final d in dbg.take(20)) Builder(builder: (context) {
            final st = '${d['s']}';
            final t = DateTime.fromMillisecondsSinceEpoch((d['t'] as num?)?.toInt() ?? 0);
            final msg = st.startsWith('read') ? '✅ اتقرت (${st.split(':').last} شقة)' : {
              'not_update': '🤷 Gemini قال دي مش صورة أبديت',
              'ocr': '🔍 اتقرت على الموبايل — بتتطبق لما تفتح التطبيق',
              'not_update_ocr': '🖼️ صورة عادية (مفيهاش كلام أبديت) — ما اتبعتتش لـ Gemini',
              'gemini_fail': '⚠️ Gemini مكانش رادد — هيحاول تاني لوحده',
              'no_file': '📵 الصورة ما اتحملتش على الموبايل — افتح الجروب يتحمل، أو شغّل تحميل الصور التلقائي',
              'same_img': '♻️ نفس صورة اتقرت قبل كده',
              'ph_fix': '🎯 الصورة اتعرف جروبها بالظبط من الإشعار (مش بالوقت)',
            }[st] ?? st;
            final bad = !st.startsWith('read') && st != 'same_img' && st != 'ph_fix' && st != 'not_update_ocr' && st != 'ocr';
            return Card(color: bad ? const Color(0xFFFFF4E0) : null, child: ListTile(dense: true,
              title: Text('${'${d['g']}'.isEmpty ? 'واتساب الأعمال' : d['g']} • ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(msg),
              trailing: bad ? TextButton(onPressed: () => readPicked(context), child: const Text('اقراها بإيدك')) : null));
          }),
        ],
        if (log.isNotEmpty) ...[
          const Text('آخر التحديثات:', style: TextStyle(fontWeight: FontWeight.w800)),
          for (final l in log.take(25))
            Card(child: ListTile(dense: true, title: Text(str(l['m'])), subtitle: Text('${str(l['g'])} • ${str(l['at']).replaceFirst('T', ' ').split('.').first}'), trailing: Store.I.villa(str(l['vid'])) == null ? null : const Icon(Icons.chevron_left), onTap: Store.I.villa(str(l['vid'])) == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => VillaPage(str(l['vid'])))))),
        ],
        ]),
      ]),
    );
  }
}
