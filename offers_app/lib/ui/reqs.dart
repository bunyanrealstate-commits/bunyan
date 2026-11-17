import 'package:flutter/material.dart';
import '../core/model.dart';
import '../core/native.dart';
import '../core/reqs.dart';
import '../core/store.dart';
import 'client.dart';
import 'send.dart';
import 'theme.dart';
import 'thumb.dart';

String _ago(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  final m = DateTime.now().difference(d).inMinutes;
  if (m < 60) return 'من $m دقيقة';
  if (m < 1440) return 'من ${m ~/ 60} ساعة';
  return 'من ${m ~/ 1440} يوم';
}

String _dt(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  final n = DateTime.now();
  final t = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  if (d.year == n.year && d.month == n.month && d.day == n.day) return 'النهارده $t';
  final tm = n.add(const Duration(days: 1));
  if (d.year == tm.year && d.month == tm.month && d.day == tm.day) return 'بكره $t';
  return '${d.day}/${d.month} $t';
}

String reqSummary(Obj r) {
  final tl = ((r['types'] as List?) ?? []).map(str).toSet();
  final ts = tl.where((t) => !(t == '1bk2b' && tl.contains('1bk')) && !(t == '2bk2b' && tl.contains('2bk'))).map(typeName).join(' / ');
  final pay = {'mo': 'شهري', '1': 'دفعة واحدة', '3': '3 دفعات'}[str(r['pay'])] ?? '';
  return [if (ts.isNotEmpty) ts, if (pay.isNotEmpty) pay, if (numOf(r['budget']) > 0) '${money(numOf(r['budget']))} درهم', if (str(r['area']).isNotEmpty) str(r['area'])].join(' • ');
}

/// 👥 العملاء: الطلبات الجديدة، اللي محتاجين متابعة، المعاينات، واللي نزلتلهم شقق جديدة
class ReqsPage extends StatelessWidget {
  const ReqsPage({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Store.I, builder: (context, _) {
        final all = Reqs.all;
        final nw = all.where((r) => r['st'] == 'new').toList();
        final due = all.where(Reqs.dueFollow).toList();
        final fresh = Reqs.newFor();
        final now = DateTime.now();
        final views = Reqs.views.where((v) => (DateTime.tryParse(str(v['at'])) ?? DateTime(2000)).isAfter(now.subtract(const Duration(hours: 2)))).toList()..sort((a, b) => str(a['at']).compareTo(str(b['at'])));
        final rest = all.where((r) => Reqs.open(r) && r['st'] != 'new' && !due.contains(r) && !fresh.contains(r)).toList();
        final done = all.where((r) => !Reqs.open(r)).toList();
        final dmOn = Store.I.cfg['dm'] == true;
        return Scaffold(
          appBar: AppBar(title: const Text('👥 العملاء')),
          body: ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 100), children: [
            if (!dmOn) Card(color: const Color(0xFFFFF4E0), child: SwitchListTile(value: false, onChanged: (_) => _dm(context, true), title: const Text('📩 اقرا طلبات العملاء من الواتساب', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('العميل يكتب «عايز غرفة وصالة 3500» ← يجيلك إشعار والشقق المناسبة جاهزة. مفيش حاجة بتتبعت غير لما تدوس.'))),
            _Today(nw: nw.length, due: due.length, views: views.where((v) => _dt(str(v['at'])).startsWith('النهارده')).length, fresh: fresh.length),
            Builder(builder: (context) {
              final n = DateTime.now();
              final ds = objs(Store.I.D['deals']).where((d) { final t = DateTime.tryParse(str(d['at'])); return t != null && t.year == n.year && t.month == n.month; }).toList();
              if (objs(Store.I.D['deals']).isEmpty) return const SizedBox.shrink();
              return Card(color: const Color(0xFFE6F6EC), child: ExpansionTile(title: Text('💰 الشهر ده: ${ds.length} صفقة • ${money(ds.fold<double>(0, (a, d) => a + numOf(d['comm'])))} درهم عمولة', style: const TextStyle(fontWeight: FontWeight.w800)), children: [
                for (final d in objs(Store.I.D['deals']).take(30)) ListTile(dense: true, title: Text('${str(d['n'])}${str(d['unit']).isNotEmpty ? ' — ${d['unit']}' : ''}'), subtitle: Text('${_dt(str(d['at']))}${numOf(d['comm']) > 0 ? ' • ${money(numOf(d['comm']))} درهم' : ''}')),
              ]));
            }),
            if (fresh.isNotEmpty) ..._sec(context, '🆕 نزلتلهم شقق جديدة تناسبهم', fresh, (r) => '${Reqs.fresh(r).length} شقة جديدة'),
            if (nw.isNotEmpty) ..._sec(context, '📩 طلبات جديدة', nw, (r) => '${Reqs.matches(r).length} شقة تناسبه • ${_ago(str(r['at']))}'),
            if (due.isNotEmpty) ..._sec(context, '🔔 محتاجين متابعة', due, (r) => 'بعتله ${((r['sent'] as List?) ?? []).length} شقة ${_ago(str(r['sentAt']))}'),
            if (views.isNotEmpty) ...[
              const _H('📅 المعاينات'),
              for (final v in views) Card(child: ListTile(leading: const Icon(Icons.event, color: kAc), title: Text('${_dt(str(v['at']))} • ${str(v['n'])}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(str(v['what'])), onTap: () { final r = Reqs.byId(str(v['rid'])); if (r != null) Navigator.push(context, MaterialPageRoute(builder: (_) => ReqPage(str(r['id'])))); },
                trailing: IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () async { (Store.I.D['views'] as List).remove(v); await Store.I.save(); await Reqs.pushSummary(); }))),
            ],
            if (rest.isNotEmpty) ..._sec(context, '📤 شغالين', rest, (r) => r['st'] == 'view' ? 'عنده معاينة' : 'بعتله ${((r['sent'] as List?) ?? []).length} شقة ${_ago(str(r['sentAt']))}'),
            if (done.isNotEmpty) ExpansionTile(title: Text('✅ خلصت (${done.length})', style: const TextStyle(fontWeight: FontWeight.w800)), children: [for (final r in done.take(40)) _tile(context, r, str(r['res']))]),
            if (all.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('لسه مفيش طلبات. أول ما عميل يكتبلك على الواتساب إنه بيدوّر على شقة هيظهر هنا — أو دوس «＋ طلب».', style: TextStyle(color: kMuted))),
          ]),
          floatingActionButton: SendQ.I.active ? null : FloatingActionButton.extended(onPressed: () => _new(context), icon: const Icon(Icons.person_add_alt_1), label: const Text('طلب')),
        );
      });

  List<Widget> _sec(BuildContext context, String t, List<Obj> l, String Function(Obj) sub) => [_H(t), for (final r in l) _tile(context, r, sub(r))];

  Widget _tile(BuildContext context, Obj r, String sub) => Card(child: ListTile(
        leading: CircleAvatar(backgroundColor: const Color(0xFFD5EEF0), child: Text(str(r['n']).isEmpty ? '#' : str(r['n']).characters.first, style: const TextStyle(fontWeight: FontWeight.w800, color: kInk))),
        title: Text(str(r['n']).isEmpty ? '+${str(r['p'])}' : str(r['n']), style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${reqSummary(r)}\n$sub', style: const TextStyle(fontSize: 12.5)),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_left),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReqPage(str(r['id'])))),
      ));

  Future<void> _dm(BuildContext context, bool b) async {
    if (b && !await confirmDlg(context, 'التطبيق هيقرا رسايل الشات الخاص اللي بتوصل في الإشعارات علشان يلاقي طلبات الشقق.\nالرسايل بتفضل على موبايلك ومبتتبعتش لأي حتة، ومفيش رد بيتبعت لوحده.', ok: 'شغّل')) return;
    Store.I.cfg['dm'] = b;
    await Store.I.saveCfg();
    try { await Native.ch.invokeMethod('dmOn', {'on': b}); await Native.ch.invokeMethod('perms'); } catch (_) {}
    Store.I.notify();
  }

  Future<void> _new(BuildContext context) async {
    final c = await pickClient(context);
    if (c == null || !context.mounted) return;
    final o = await formDlg(context, 'العميل عايز إيه؟', [const FS('t', 'اكتب أو الصق رسالته (زي: غرفة وصالة شهري 3500)', multi: true)], ok: 'دوّر');
    if (o == null || !context.mounted) return;
    final r = Reqs.add(name: c['n'] ?? '', phone: c['p'] ?? '', text: o['t'] ?? '', lang: c['lang'] ?? '');
    await Store.I.save();
    if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ReqPage(str(r['id']))));
  }
}

class _H extends StatelessWidget {
  final String t;
  const _H(this.t);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(2, 14, 2, 4), child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)));
}

class _Today extends StatelessWidget {
  final int nw, due, views, fresh;
  const _Today({required this.nw, required this.due, required this.views, required this.fresh});
  @override
  Widget build(BuildContext context) {
    Widget b(String n, String l, Color c) => Expanded(child: Column(children: [Text(n, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c)), Text(l, style: const TextStyle(fontSize: 11.5, color: kMuted), textAlign: TextAlign.center)]));
    return Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(children: [
      b('$nw', 'طلب جديد', kAc2), b('$due', 'متابعة', kGold), b('$views', 'معاينة النهارده', kAc), b('$fresh', 'نزلتلهم شقق', kOk),
    ])));
  }
}

/// صفحة طلب عميل: الطلب ← الشقق المناسبة ← ابعت / معاينة / متابعة / خلص
class ReqPage extends StatefulWidget {
  final String id;
  const ReqPage(this.id, {super.key});
  @override
  State<ReqPage> createState() => _ReqState();
}

class _ReqState extends State<ReqPage> {
  final picked = <String>{};
  bool terms = false, init = false;
  late final bc = TextEditingController();

  @override
  void dispose() {
    // اللي شفته خلاص ميتحسبش «جديد» تاني
    final r = Reqs.byId(widget.id);
    if (r != null && r['st'] != 'new') { final s = ((r['seen'] as List?) ?? (r['seen'] = <dynamic>[])); for (final x in Reqs.matches(r)) { final k = Reqs.key(x['v'] as Obj, x['u'] as Obj); if (!s.contains(k)) s.add(k); } Future.microtask(Store.I.save); }
    bc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Listenable.merge([Store.I, SendQ.I]), builder: (context, _) {
        final r = Reqs.byId(widget.id);
        if (r == null) return const Scaffold(body: Center(child: Text('الطلب اتمسح')));
        if (!init) {
          init = true;
          bc.text = numOf(r['budget']) > 0 ? numOf(r['budget']).round().toString() : '';
          final fr = Reqs.fresh(r);
          for (final x in (fr.isNotEmpty ? fr : Reqs.matches(r)).take(5)) { picked.add(Reqs.key(x['v'] as Obj, x['u'] as Obj)); }
        }
        final types = ((r['types'] as List?) ?? []).map(str).toSet();
        final res = Reqs.matches(r);
        final sent = ((r['sent'] as List?) ?? []).map(str).toSet();
        final sel = res.where((x) => picked.contains(Reqs.key(x['v'] as Obj, x['u'] as Obj))).toList();
        final en = r['lang'] == 'en';
        return Scaffold(
          appBar: AppBar(title: Text(str(r['n']).isEmpty ? '+${str(r['p'])}' : str(r['n'])), actions: [
            IconButton(tooltip: 'امسح', icon: const Icon(Icons.delete_outline, color: kRed), onPressed: () async { if (await confirmDlg(context, 'تمسح الطلب ده؟', ok: 'امسح')) { (Store.I.D['reqs'] as List).remove(r); await Store.I.save(); if (context.mounted) Navigator.pop(context); } }),
          ]),
          body: ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 110), children: [
            if (str(r['txt']).isNotEmpty) Card(color: const Color(0xFFF4F7F8), child: Padding(padding: const EdgeInsets.all(10), child: Text('💬 ${str(r['txt'])}', style: const TextStyle(fontSize: 13)))),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final t in kTypes.where((t) => t[0] != 'x')) FilterChip(label: Text(t[1], style: TextStyle(color: types.contains(t[0]) ? Colors.white : kInk, fontSize: 12.5)), selected: types.contains(t[0]), showCheckmark: false, onSelected: (b) { b ? types.add(t[0]) : types.remove(t[0]); r['types'] = types.toList(); Store.I.save(); }),
            ]),
            const SizedBox(height: 8),
            SegmentedButton<String>(segments: const [ButtonSegment(value: 'mo', label: Text('شهري')), ButtonSegment(value: '1', label: Text('دفعة واحدة')), ButtonSegment(value: '3', label: Text('3 دفعات')), ButtonSegment(value: 'any', label: Text('الكل'))], selected: {str(r['pay']).isEmpty ? 'any' : str(r['pay'])}, onSelectionChanged: (s) { r['pay'] = s.first; Store.I.save(); }),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: bc, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الميزانية (شهري أو سنوي)', suffixText: 'درهم'), onChanged: (v) { r['budget'] = numOf(v); Store.I.save(); })),
              const SizedBox(width: 8),
              SegmentedButton<String>(segments: const [ButtonSegment(value: 'ar', label: Text('عربي')), ButtonSegment(value: 'en', label: Text('EN'))], selected: {en ? 'en' : 'ar'}, onSelectionChanged: (s) { r['lang'] = s.first; Store.I.save(); }),
            ]),
            Align(alignment: AlignmentDirectional.centerStart, child: FilterChip(label: Text('📄 ضيف الشروط في الرسالة', style: TextStyle(color: terms ? Colors.white : kInk, fontSize: 12.5)), selected: terms, showCheckmark: false, onSelected: (b) => setState(() => terms = b))),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(onPressed: () => _view(r, sel.isNotEmpty ? sel : res), icon: const Icon(Icons.event), label: const Text('معاينة')),
              if (sel.isNotEmpty) OutlinedButton.icon(onPressed: () => _link(r, sel), icon: const Icon(Icons.link), label: const Text('لينك عرض')),
              if (str(r['p']).isNotEmpty) OutlinedButton.icon(onPressed: () => _follow(r), icon: const Icon(Icons.notifications_active_outlined), label: const Text('تابع معاه')),
              OutlinedButton.icon(onPressed: () => _done(r), icon: const Icon(Icons.check_circle_outline), label: Text(Reqs.open(r) ? 'خلص' : 'رجّعه مفتوح')),
            ]),
            Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(res.isEmpty ? 'مفيش حاجة متاحة دلوقتي تناسبه — هيتفكر لما ينزل أبديت فيه حاجة تناسبه 🔔' : '${res.length} شقة تناسبه — علّم اللي تبعته', style: const TextStyle(fontWeight: FontWeight.w700, color: kMuted))),
            for (final x in res) _row(r, x, sent),
          ]),
          bottomNavigationBar: const SafeArea(child: SendBar()),
          floatingActionButton: sel.isEmpty || SendQ.I.active ? null : FloatingActionButton.extended(onPressed: () => _send(r, sel), backgroundColor: const Color(0xFF25D366), icon: const Icon(Icons.send, color: Colors.white), label: Text('ابعت ${sel.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
        );
      });

  Widget _row(Obj r, Map<String, dynamic> x, Set<String> sent) {
    final v = x['v'] as Obj, u = x['u'] as Obj, k = Reqs.key(v, u), on = picked.contains(k);
    final vids = (u['videos'] as List?)?.map(str).toList() ?? [];
    final wasSent = sent.contains(k), isNew = !wasSent && !((r['seen'] as List?) ?? []).contains(k) && r['st'] != 'new';
    return Card(color: on ? const Color(0xFFE3F4F5) : null, child: InkWell(borderRadius: BorderRadius.circular(16), onTap: () => setState(() => on ? picked.remove(k) : picked.add(k)), child: Padding(padding: const EdgeInsets.all(8), child: Row(children: [
      VThumb(vids.isEmpty ? null : vids.first, w: 70, h: 70),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${isNew ? '🆕 ' : ''}${wasSent ? '✓ ' : ''}${typeName(u['type'])}${str(u['no']).isNotEmpty ? ' • ${u['no']}' : ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
        Text('${str(v['name'])} ${str(v['no'])}', style: const TextStyle(color: kMuted, fontSize: 12.5)),
        Text(Price.text(u), style: const TextStyle(color: kOk, fontWeight: FontWeight.w700, fontSize: 12.5)),
        if (wasSent) const Text('اتبعتله قبل كده', style: TextStyle(color: kMuted, fontSize: 11.5)),
      ])),
      Checkbox(value: on, onChanged: (_) => setState(() => on ? picked.remove(k) : picked.add(k))),
    ]))));
  }

  Future<void> _send(Obj r, List<Map<String, dynamic>> sel) async {
    var c = {'n': str(r['n']), 'p': str(r['p']), 'lang': str(r['lang'])};
    if (c['p']!.isEmpty) { final pc = await pickClient(context); if (pc == null || !mounted) return; c = {...pc, 'lang': str(r['lang'])}; r['p'] = pc['p']; if (str(r['n']).isEmpty) r['n'] = pc['n']; }
    await rememberClient(c);
    if (!mounted) return;
    await SendQ.I.start(context, c, sel, str(r['pay']).isEmpty ? 'any' : str(r['pay']), terms: terms, whenDone: () => Reqs.markSent(r, sel));
    setState(() => picked.clear());
  }

  Future<void> _link(Obj r, List<Map<String, dynamic>> sel) async {
    var c = {'n': str(r['n']), 'p': str(r['p']), 'lang': str(r['lang'])};
    if (c['p']!.isEmpty) { final pc = await pickClient(context); if (pc == null || !mounted) return; c = {...pc, 'lang': str(r['lang'])}; r['p'] = pc['p']; }
    if (!mounted) return;
    if (await sendOfferLink(context, c, sel, str(r['pay']).isEmpty ? 'any' : str(r['pay']))) { await Reqs.markSent(r, sel); if (mounted) setState(() => picked.clear()); }
  }

  Future<void> _follow(Obj r) async {
    final o = await formDlg(context, '🔔 رسالة متابعة', [FS('t', 'الرسالة (تقدر تعدلها)', v: Reqs.followText(r), multi: true)], ok: 'افتح الواتساب');
    if (o == null) return;
    await Native.ch.invokeMethod('openChat', {'phone': Native.phone(str(r['p'])), 'text': o['t'] ?? ''});
    r['follow'] = DateTime.now().add(const Duration(days: 2)).toIso8601String();
    await Store.I.save();
    await Reqs.pushSummary();
  }

  Future<void> _done(Obj r) async {
    if (!Reqs.open(r)) { r['st'] = 'sent'; await Store.I.save(); return; }
    final why = await pickDlg(context, 'خلص إزاي؟', const [['rent', '🎉 أجّر'], ['other', '🏠 لقى حاجة تانية'], ['no', '❌ مبقاش محتاج']]);
    if (why == null) return;
    if (why == 'rent' && mounted) {
      final opts = [...Reqs.matches(r)];
      final sentK = ((r['sent'] as List?) ?? []).map(str).toSet();
      opts.sort((a, b) => (sentK.contains(Reqs.key(b['v'] as Obj, b['u'] as Obj)) ? 1 : 0) - (sentK.contains(Reqs.key(a['v'] as Obj, a['u'] as Obj)) ? 1 : 0));
      final k = opts.isEmpty ? null : await pickDlg(context, 'أجّر أنهي شقة؟', [for (var i = 0; i < opts.length && i < 30; i++) ['$i', '${typeName((opts[i]['u'] as Obj)['type'])} ${str((opts[i]['u'] as Obj)['no'])} — ${str((opts[i]['v'] as Obj)['name'])} ${str((opts[i]['v'] as Obj)['no'])}'], ['-', 'شقة مش في الليستة']]);
      if (!mounted) return;
      final o = await formDlg(context, '🎉 مبروك! العمولة كام؟', [const FS('c', 'العمولة بالدرهم (فاضي = مش عارف)', num: true)], ok: 'سجّل');
      if (o == null) return;
      final x = k == null || k == '-' ? null : opts[int.parse(k)];
      if (x != null) { (x['u'] as Obj)['avail'] = false; (x['u'] as Obj)['rentedTo'] = str(r['n']); }
      ((Store.I.D['deals'] as List?) ?? (Store.I.D['deals'] = <dynamic>[])).insert(0, {'at': DateTime.now().toIso8601String(), 'n': str(r['n']), 'p': str(r['p']), 'rid': r['id'], if (x != null) 'unit': '${typeName((x['u'] as Obj)['type'])} ${str((x['u'] as Obj)['no'])} — ${str((x['v'] as Obj)['name'])} ${str((x['v'] as Obj)['no'])}', 'comm': numOf(o['c'])});
    }
    r['st'] = 'done'; r['res'] = {'rent': '🎉 أجّر', 'other': 'لقى حاجة تانية', 'no': 'مبقاش محتاج'}[why]; r['doneAt'] = DateTime.now().toIso8601String();
    await Store.I.save();
    await Reqs.pushSummary();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _view(Obj r, List<Map<String, dynamic>> opts) async {
    if (opts.isEmpty) { toast(context, 'اختار شقة الأول'); return; }
    final k = opts.length == 1 ? '0' : await pickDlg(context, 'معاينة أنهي شقة؟', [for (var i = 0; i < opts.length; i++) ['$i', '${typeName((opts[i]['u'] as Obj)['type'])} ${str((opts[i]['u'] as Obj)['no'])} — ${str((opts[i]['v'] as Obj)['name'])} ${str((opts[i]['v'] as Obj)['no'])}']]);
    if (k == null || !mounted) return;
    final x = opts[int.parse(k)];
    final d = await showDatePicker(context: context, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 60)), initialDate: DateTime.now());
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 17, minute: 0));
    if (t == null) return;
    final v = x['v'] as Obj, u = x['u'] as Obj;
    await Reqs.addView(r, DateTime(d.year, d.month, d.day, t.hour, t.minute), '${typeName(u['type'])} ${str(u['no'])} — ${str(v['name'])} ${str(v['no'])}${str(v['area']).isNotEmpty ? ' (${v['area']})' : ''}');
    await Reqs.pushSummary();
    if (mounted) toast(context, '📅 اتسجلت — هيفكرك قبلها بساعة');
  }
}
