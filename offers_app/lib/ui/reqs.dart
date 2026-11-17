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

String reqName(Obj r) => str(r['n']).isNotEmpty ? str(r['n']) : (str(r['cn']).isNotEmpty ? str(r['cn']) : '+${str(r['p'])}');

String reqSummary(Obj r) {
  final tl = ((r['types'] as List?) ?? []).map(str).toSet();
  final fur = r['fur'] == true ? 'مفروش' : (r['fur'] == false ? 'فاضي' : '');
  final ts = tl.where((t) => !(t == '1bk2b' && tl.contains('1bk')) && !(t == '2bk2b' && tl.contains('2bk'))).map(typeName).join(' / ');
  final pay = {'mo': 'شهري', '1': 'دفعة واحدة', '3': '3 دفعات'}[str(r['pay'])] ?? '';
  final w = DateTime.tryParse(str(r['when']));
  return [if (ts.isNotEmpty) ts, if (fur.isNotEmpty) fur, if (w != null) '📅 من ${w.day}/${w.month}', if (pay.isNotEmpty) pay, if (numOf(r['budget']) > 0) '${money(numOf(r['budget']))} درهم', if (str(r['area']).isNotEmpty) str(r['area'])].join(' • ');
}

/// 👥 العملاء: بحث + فلتر بسيط، ودوس على أي عميل تبعتله
class ReqsPage extends StatefulWidget {
  const ReqsPage({super.key});
  @override
  State<ReqsPage> createState() => _ReqsState();
}

class _ReqsState extends State<ReqsPage> {
  String q = '', f = 'all';
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Store.I, builder: (context, _) {
        final all = Reqs.all;
        final now = DateTime.now();
        final fid = Reqs.newFor().map((r) => str(r['id'])).toSet();
        bool soon(Obj r) { final w = DateTime.tryParse(str(r['when'])); return Reqs.open(r) && w != null && w.difference(now).inDays <= 7 && w.difference(now).inDays >= -3; }
        final views = Reqs.views.where((v) => (DateTime.tryParse(str(v['at'])) ?? DateTime(2000)).isAfter(now.subtract(const Duration(hours: 2)))).toList()..sort((a, b) => str(a['at']).compareTo(str(b['at'])));
        final cnt = {
          'all': all.where(Reqs.open).length,
          'fresh': fid.length,
          'soon': all.where(soon).length,
          'due': all.where(Reqs.dueFollow).length,
          'done': all.where((r) => !Reqs.open(r)).length,
        };
        final ql = q.trim().toLowerCase();
        var l = all.where((r) {
          switch (f) {
            case 'fresh': if (!fid.contains(str(r['id']))) return false; break;
            case 'soon': if (!soon(r)) return false; break;
            case 'due': if (!Reqs.dueFollow(r)) return false; break;
            case 'done': if (Reqs.open(r)) return false; break;
            default: if (!Reqs.open(r)) return false;
          }
          if (ql.isEmpty) return true;
          return '${reqName(r)} ${str(r['cn'])} ${str(r['p'])} ${reqSummary(r)}'.toLowerCase().contains(ql);
        }).toList();
        // اللي ليهم شقق جديدة فوق، وبعدين الأحدث
        l.sort((a, b) { final x = fid.contains(str(a['id'])) ? 0 : 1, y = fid.contains(str(b['id'])) ? 0 : 1; return x != y ? x - y : str(b['at']).compareTo(str(a['at'])); });
        String sub(Obj r) {
          if (fid.contains(str(r['id']))) return '🆕 ${Reqs.fresh(r).length} شقة جديدة تناسبه';
          if (Reqs.dueFollow(r)) return '↩️ بعتله ${_ago(str(r['sentAt']))} — تابع معاه';
          if (!Reqs.open(r)) return '✅ ${str(r['res'])}';
          if (r['st'] == 'sent') return '📤 بعتله ${((r['sent'] as List?) ?? []).length} شقة ${_ago(str(r['sentAt']))}';
          return '${Reqs.matches(r).length} شقة تناسبه دلوقتي';
        }
        const labels = {'all': 'الكل', 'fresh': '🆕 ليهم جديد', 'soon': '📅 قريب', 'due': '↩️ متابعة', 'done': '✅ خلصت'};
        return Scaffold(
          appBar: AppBar(title: const Text('👥 العملاء')),
          body: Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(14, 6, 14, 4), child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'دوّر باسم العميل أو رقمه', isDense: true), onChanged: (v) => setState(() => q = v))),
            SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10), children: [
              for (final k in labels.keys) Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: ChoiceChip(label: Text('${labels[k]} ${cnt[k]}'), selected: f == k, onSelected: (_) => setState(() => f = k))),
            ])),
            Expanded(child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
              itemCount: l.length + 2,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Column(children: [
                    Card(child: ListTile(dense: true, leading: const Icon(Icons.contacts_outlined, color: kAc), title: const Text('📇 ضيف عملاء من جهات الاتصال', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('الأحدث فوق — علّم اللي عايزهم بس'), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PickContactsPage())))),
                    for (final v in views) Card(color: const Color(0xFFE3F4F5), child: ListTile(leading: const Icon(Icons.event, color: kAc), title: Text('معاينة ${_dt(str(v['at']))} • ${str(v['n'])}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(str(v['what'])), onTap: () { final r = Reqs.byId(str(v['rid'])); if (r != null) Navigator.push(context, MaterialPageRoute(builder: (_) => ReqPage(str(r['id'])))); },
                        trailing: IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () async { (Store.I.D['views'] as List).remove(v); await Store.I.save(); await Reqs.pushSummary(); }))),
                  ]);
                }
                if (i == l.length + 1) {
                  if (l.isNotEmpty) return const SizedBox.shrink();
                  return Padding(padding: const EdgeInsets.all(20), child: Text(all.isEmpty ? 'لسه مفيش عملاء. سجّل العميل في الموبايل باسم زي «Studio Fur 3500 Suzanne» وهيظهر هنا لوحده — أو دوس «＋ عميل».' : 'مفيش حد هنا', style: const TextStyle(color: kMuted)));
                }
                return _tile(context, l[i - 1], sub(l[i - 1]));
              },
            )),
          ]),
          floatingActionButton: SendQ.I.active ? null : FloatingActionButton.extended(onPressed: () => _new(context), icon: const Icon(Icons.person_add_alt_1), label: const Text('عميل جديد')),
        );
      });

  Widget _tile(BuildContext context, Obj r, String sub) => Card(child: ListTile(
        leading: CircleAvatar(backgroundColor: const Color(0xFFD5EEF0), child: Text(reqName(r).characters.first, style: const TextStyle(fontWeight: FontWeight.w800, color: kInk))),
        title: Text(reqName(r), style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${reqSummary(r)}\n$sub', style: const TextStyle(fontSize: 12.5)),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_left),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReqPage(str(r['id'])))),
      ));

  Future<void> _new(BuildContext context) async {
    final id = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const NewClientPage()));
    if (id != null && context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ReqPage(id)));
  }
}

/// 📇 اختار العملاء من جهات الاتصال: أسامي زي «Studio Fur 3500 Suzanne»، الأحدث فوق
class PickContactsPage extends StatefulWidget {
  const PickContactsPage({super.key});
  @override
  State<PickContactsPage> createState() => _PickContactsState();
}

class _PickContactsState extends State<PickContactsPage> {
  List<Map<String, String>> cs = [];
  final sel = <String>{};
  bool loading = true;
  String q = '';
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final all = await Native.contacts();
    final l = all.where((c) => parseContactName(c['n'] ?? '') != null).toList()
      ..sort((a, b) => (int.tryParse(b['id'] ?? '') ?? 0).compareTo(int.tryParse(a['id'] ?? '') ?? 0));
    if (mounted) setState(() { cs = l; loading = false; });
  }

  Future<void> _add() async {
    final n = await Reqs.importContacts(cs.where((c) => sel.contains(c['p'])).toList(), all: true);
    if (mounted) { toast(context, '✅ اتضاف $n عميل'); Navigator.pop(context); }
  }

  @override
  Widget build(BuildContext context) {
    final have = Reqs.all.map((r) => str(r['p'])).toSet();
    final l = cs.where((c) => q.isEmpty || (c['n'] ?? '').toLowerCase().contains(q.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('📇 اختار العملاء')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(14, 6, 14, 4), child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'دوّر', isDense: true), onChanged: (v) => setState(() => q = v))),
        if (loading) const Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()),
        if (!loading && cs.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('مالقيتش أسامي فيها طلب (زي Studio Fur 3500 Suzanne) — أو وافق على إذن جهات الاتصال', style: TextStyle(color: kMuted))),
        Expanded(child: ListView.builder(padding: const EdgeInsets.fromLTRB(8, 0, 8, 100), itemCount: l.length, itemBuilder: (context, i) {
          final c = l[i], p = c['p'] ?? '', added = have.contains(p);
          return CheckboxListTile(dense: true, value: added || sel.contains(p), onChanged: added ? null : (b) => setState(() => b == true ? sel.add(p) : sel.remove(p)),
              title: Text(c['n'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(added ? '✅ متضاف' : '+$p'));
        })),
      ]),
      floatingActionButton: sel.isEmpty ? null : FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.check), label: Text('ضيف ${sel.length}')),
    );
  }
}

/// ➕ عميل جديد: الاسم + الموبايل + طلبه — صفحة واحدة
class NewClientPage extends StatefulWidget {
  const NewClientPage({super.key});
  @override
  State<NewClientPage> createState() => _NewClientState();
}

class _NewClientState extends State<NewClientPage> {
  final n = TextEditingController(), p = TextEditingController(), b = TextEditingController(), note = TextEditingController();
  final types = <String>{};
  bool? fur;
  String lang = 'ar';
  static const _t = [['st', 'استديو'], ['1bk', 'غرفة وصالة'], ['2bk', 'غرفتين وصالة'], ['3bk', '3 غرف']];

  Future<void> _contact() async {
    final c = await pickClient(context);
    if (c == null || !mounted) return;
    setState(() { n.text = c['n'] ?? ''; p.text = c['p'] ?? ''; lang = c['lang'] ?? lang; });
  }

  Future<void> _save() async {
    final ph = Native.phone(p.text);
    if (ph.length < 9) { toast(context, '⚠️ اكتب رقم الموبايل'); return; }
    if (types.isEmpty) { toast(context, '⚠️ اختار نوع الشقة'); return; }
    final old = Reqs.all.where((r) => str(r['p']) == ph && Reqs.open(r)).firstOrNull;
    final r = old ?? Reqs.add(name: n.text.trim(), phone: ph, text: note.text.trim(), lang: lang);
    if (old != null) { r['n'] = n.text.trim(); r['txt'] = note.text.trim(); r['lang'] = lang; }
    r['types'] = [for (final t in types) ...(t == '1bk' ? ['1bk', '1bk2b'] : t == '2bk' ? ['2bk', '2bk2b'] : [t])];
    r['fur'] = fur;
    final bud = numOf(b.text);
    if (bud > 0) r['budget'] = Price.budgetMonthly(bud < 1000 ? bud * 1000 : bud);
    if (str(r['pay']).isEmpty) r['pay'] = 'any';
    r['st'] = 'wait'; r['src'] = 'manual';
    r['seen'] = <dynamic>[];
    await Store.I.save();
    if (mounted) Navigator.pop(context, str(r['id']));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('➕ عميل جديد')),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 120), children: [
          TextField(controller: n, decoration: const InputDecoration(labelText: 'اسم العميل', prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: 12),
          TextField(controller: p, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'رقم الموبايل', hintText: '05xxxxxxxx', prefixIcon: const Icon(Icons.phone_outlined), suffixIcon: IconButton(tooltip: 'من جهات الاتصال', icon: const Icon(Icons.contacts_outlined), onPressed: _contact))),
          const SizedBox(height: 18),
          const Text('عايز إيه؟', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 6, children: [for (final t in _t) FilterChip(label: Text(t[1], style: TextStyle(color: types.contains(t[0]) ? Colors.white : kInk)), selected: types.contains(t[0]), showCheckmark: false, onSelected: (x) => setState(() => x ? types.add(t[0]) : types.remove(t[0])))]),
          const SizedBox(height: 12),
          SegmentedButton<String>(segments: const [ButtonSegment(value: 'f', label: Text('🛋️ مفروش')), ButtonSegment(value: 'e', label: Text('فاضي')), ButtonSegment(value: 'x', label: Text('مش مهم'))],
              selected: {fur == true ? 'f' : fur == false ? 'e' : 'x'}, onSelectionChanged: (v) => setState(() => fur = v.first == 'f' ? true : v.first == 'e' ? false : null)),
          const SizedBox(height: 14),
          TextField(controller: b, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الميزانية (شهري أو سنوي)', hintText: 'زي 3500 أو 40000', prefixIcon: Icon(Icons.payments_outlined), suffixText: 'درهم')),
          const SizedBox(height: 12),
          TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)', hintText: 'زي: يسكن أول ديسمبر • يفضل حمامين')),
          const SizedBox(height: 12),
          SegmentedButton<String>(segments: const [ButtonSegment(value: 'ar', label: Text('🇦🇪 رسالة عربي')), ButtonSegment(value: 'en', label: Text('🇬🇧 English'))], selected: {lang}, onSelectionChanged: (v) => setState(() => lang = v.first)),
        ]),
        floatingActionButton: FloatingActionButton.extended(onPressed: _save, icon: const Icon(Icons.check), label: const Text('حفظ ودوّر له')),
      );
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
          appBar: AppBar(title: Text(reqName(r)), actions: [
            IconButton(tooltip: 'امسح', icon: const Icon(Icons.delete_outline, color: kRed), onPressed: () async { if (await confirmDlg(context, 'تمسح الطلب ده؟', ok: 'امسح')) { (Store.I.D['reqs'] as List).remove(r); await Store.I.save(); if (context.mounted) Navigator.pop(context); } }),
          ]),
          body: ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 110), children: [
            if (str(r['txt']).isNotEmpty) Card(color: const Color(0xFFF4F7F8), child: Padding(padding: const EdgeInsets.all(10), child: Text('💬 ${str(r['txt'])}', style: const TextStyle(fontSize: 13)))),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final t in kTypes.where((t) => t[0] != 'x')) FilterChip(label: Text(t[1], style: TextStyle(color: types.contains(t[0]) ? Colors.white : kInk, fontSize: 12.5)), selected: types.contains(t[0]), showCheckmark: false, onSelected: (b) { b ? types.add(t[0]) : types.remove(t[0]); r['types'] = types.toList(); Store.I.save(); }),
            ]),
            const SizedBox(height: 8),
            SegmentedButton<String>(segments: const [ButtonSegment(value: 'f', label: Text('🛋️ مفروش')), ButtonSegment(value: 'e', label: Text('فاضي')), ButtonSegment(value: 'x', label: Text('مش مهم'))], selected: {r['fur'] == true ? 'f' : (r['fur'] == false ? 'e' : 'x')}, onSelectionChanged: (s) { r['fur'] = s.first == 'f' ? true : (s.first == 'e' ? false : null); Store.I.save(); }),
            const SizedBox(height: 8),
            SegmentedButton<String>(showSelectedIcon: false, segments: const [ButtonSegment(value: 'mo', label: Text('شهري')), ButtonSegment(value: '1', label: Text('دفعة')), ButtonSegment(value: '2', label: Text('دفعتين')), ButtonSegment(value: '3', label: Text('3 دفعات')), ButtonSegment(value: 'any', label: Text('الكل'))], selected: {str(r['pay']).isEmpty ? 'any' : str(r['pay'])}, onSelectionChanged: (s) { r['pay'] = s.first; Store.I.save(); }),
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
