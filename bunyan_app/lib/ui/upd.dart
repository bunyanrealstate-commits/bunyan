import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'i18n.dart';
import '../core/upd.dart';
import '../core/js.dart';
import '../core/native.dart';
import 'theme.dart';
import 'dialogs.dart';

/// 📢 الأبديت — نفس تبويب بنيان القديم: ملخص + ابعت الصورة + 4 أزرار + معاينة + 6 كروت (الفلل، الأعمدة، الأرقام، الكلام، الأسعار، تعديل حر)
class UpdPage extends StatefulWidget {
  final bool inTab;
  const UpdPage({super.key, this.inTab = false});
  @override
  State<UpdPage> createState() => _UpdState();
}

const _G = Color(0xFF0B3B2C), _G2 = Color(0xFF1E8A57), _RD = Color(0xFFC81E1E);
const _cols = [['fl', 'الدور FLOOR'], ['fn', 'رقم الشقة FLAT'], ['ty', 'النوع TYPE'], ['pay', 'الدفعات / السعر'], ['mo', 'الشهري MONTHLY'], ['nt', 'الملاحظات NOTES']];

List<List<String>> _allCols(Map d) => [..._cols, for (final c in objs(d['cc'])) ['c_${c['id']}', str(c['h']).isEmpty ? 'عمود جديد' : str(c['h'])]];
List<String> _colOrder(Map d) {
  final ac = _allCols(d).map((c) => c[0]).toList();
  final o = [for (final k in lst(d['order'])) if (ac.contains('$k')) '$k'];
  for (final k in ac) { if (!o.contains(k)) o.add(k); }
  return o;
}
Map<String, dynamic> _m(Map d, String k) => (d[k] is Map<String, dynamic>) ? d[k] as Map<String, dynamic> : (d[k] = <String, dynamic>{});
String _lb(Map d, String k, String def) { final v = str(obj(d['lab'])?[k]).trim(); return v.isEmpty ? def : v; }
List<String> _phs(Map d) => [d['phone'], ...lst(d['phones'])].map((x) => str(x).replaceAll('​', '').trim()).where((x) => x.isNotEmpty).toList();

class _UpdState extends State<UpdPage> {
  String mode = 'u'; Map<String, dynamic>? d; bool busy = true, prev = false; String msg = '';
  final key = GlobalKey();
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { setState(() => busy = true); final x = await Upd.pull(mode); if (!mounted) return; setState(() { d = x; busy = false; }); }
  Future<void> _save([String? m]) async {
    setState(() {});
    final ok = await Upd.save(mode, d!);
    if (mounted) setState(() => msg = ok ? '☁️ اتحفظ واتزامن مع بنيان القديم' : '💾 اتحفظ على الموبايل');
    if (m != null && mounted) toast(context, m);
  }

  int get _tot => objs(d!['villas']).fold(0, (s, v) => s + objs(v['units']).length);
  int get _bk => objs(d!['villas']).fold(0, (s, v) => s + objs(v['units']).where((a) => truthy(a['booked'])).length);

  @override
  Widget build(BuildContext context) {
    final D = d;
    final body = busy || D == null ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.fromLTRB(10, 10, 10, 90), children: [
          _head(D),
          const SizedBox(height: 10),
          _tiles(D),
        ]));
    if (widget.inTab) return Directionality(textDirection: Tr.dir, child: body);
    return Directionality(textDirection: Tr.dir, child: Scaffold(appBar: AppBar(title: const Text('📢 الأبديت')), body: body));
  }

  /* ───── الكارت اللي فوق ───── */
  Widget _head(Map<String, dynamic> D) {
    final tot = _tot, bk = _bk;
    Widget pill(String t, Color bg, Color fg) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99), border: Border.all(color: fg.withOpacity(.25))), child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fg)));
    Widget ic(String e, String t, VoidCallback on, {bool sel = false}) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: InkWell(borderRadius: BorderRadius.circular(14), onTap: on, child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9), decoration: BoxDecoration(color: sel ? const Color(0xFFE8F5EE) : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: sel ? _G2 : kBd)),
          child: Column(children: [Text(e, style: const TextStyle(fontSize: 20)), const SizedBox(height: 2), Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800))])))));
    return BCard(c: const Color(0xFF2563EB), title: '📢 الأبديت', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        for (final o in const [['u', '🏢 غير مفروش'], ['f', '🛋 مفروش']]) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: InkWell(borderRadius: BorderRadius.circular(12), onTap: () { if (mode != o[0]) { mode = o[0]; prev = false; _load(); } },
          child: Container(padding: const EdgeInsets.symmetric(vertical: 10), alignment: Alignment.center, decoration: BoxDecoration(color: mode == o[0] ? _G : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: mode == o[0] ? _G : kBd)),
            child: Text(o[1], style: TextStyle(fontWeight: FontWeight.w900, color: mode == o[0] ? Colors.white : kInk)))))),
      ]),
      const SizedBox(height: 10),
      Text(str(D['title']), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kNavy)),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        pill('🏡 ${objs(D['villas']).length} فيلا', const Color(0xFFFFFBEB), const Color(0xFF92400E)),
        pill('🚪 $tot شقة', const Color(0xFFF8FAFC), const Color(0xFF334155)),
        pill('✅ ${tot - bk} متاحة', const Color(0xFFF0FDF4), const Color(0xFF15803D)),
        if (bk > 0) pill('🔒 $bk محجوزة', const Color(0xFFFFF7ED), const Color(0xFFC2410C)),
      ]),
      const SizedBox(height: 10),
      FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1D5FD1), minimumSize: const Size.fromHeight(48)), onPressed: _shareImg, child: const Text('📤 ابعت الصورة على الواتساب', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900))),
      const SizedBox(height: 8),
      Row(children: [
        ic('👀', prev ? 'اخفي الصورة' : 'شوف الصورة', () => setState(() => prev = !prev), sel: prev),
        ic('💾', 'احفظ', _saveImg),
        ic('💬', 'ابعت نص', () => Share.share(Upd.txt(D))),
        ic('👥', truthy(D['gname']) ? '✓ ${D['gname']}' : 'الجروب', _group, sel: truthy(D['gname'])),
      ]),
      if (msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(msg, style: const TextStyle(color: kMuted, fontSize: 11.5))),
      // المعاينة: الصورة نفسها (بتتعمل منها الصورة اللي بتتبعت)
      Offstage(offstage: !prev, child: Padding(padding: const EdgeInsets.only(top: 10), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: FittedBox(child: RepaintBoundary(key: key, child: UpdPoster(D, mode)))))),
    ]));
  }

  /* ───── الكروت الستة ───── */
  Widget _tiles(Map<String, dynamic> D) {
    final tot = _tot, bk = _bk; final P = Upd.PM(D);
    final vis = _colOrder(D).where((k) => obj(D['hc'])?[k] != true).length;
    Widget t(String ic, String title, String big, String sub, Color c, VoidCallback on, {bool sm = false}) => InkWell(borderRadius: BorderRadius.circular(16), onTap: on, child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBd), boxShadow: [BoxShadow(color: kNavy.withOpacity(.05), blurRadius: 10, offset: const Offset(0, 4))]),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$ic $title', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
              const SizedBox(height: 2),
              Text(big, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, fontSize: sm ? 15 : 22, color: c)),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: kMuted)),
            ])),
            Container(width: 4, height: 46, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(9))),
          ]),
        ));
    final L = [
      t('🏡', 'الفلل والشقق', '$tot شقة', '${tot - bk} متاحة • $bk محجوزة', const Color(0xFF16A34A), _villas),
      t('🧱', 'الأعمدة', '$vis', 'عمود ظاهر في الصورة', const Color(0xFF7C3AED), _colsEd),
      t('📞', 'أرقام التواصل', '${_phs(D).length}', _phs(D).isEmpty ? 'ضيف رقم' : _phs(D).first, const Color(0xFF0284C7), _phones),
      t('🔤', 'كلام الصورة', str(D['title']), 'العنوان • التاريخ • التأمين', const Color(0xFFD97706), _texts, sm: true),
      t('⚙️', 'الأسعار والدفعات', P['m'] == 'sep' ? 'دفعات منفصلة' : P['m'] == 'range' ? 'من دفعة لكذا' : 'سعر ثابت', 'نظام الدفعات والإيجار', const Color(0xFF475569), _prices, sm: true),
      t('📊', 'تعديل حر', 'زي الإكسيل', 'كل الشقق في جدول واحد', const Color(0xFF2563EB), _grid, sm: true),
    ];
    return Column(children: [for (var i = 0; i < L.length; i += 2) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Expanded(child: L[i]), const SizedBox(width: 8), Expanded(child: L[i + 1])]))]);
  }

  /// صفحة كاملة للتعديل (بتتحدّث مع كل تغيير)
  Future<void> _page(String title, Widget Function(StateSetter ss) build, {Widget? fab}) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Directionality(textDirection: Tr.dir, child: StatefulBuilder(builder: (ctx, ss) => Scaffold(
        appBar: AppBar(title: Text(title)), floatingActionButton: fab, body: build(ss))))))
      .then((_) { if (mounted) setState(() {}); });

  /* ───── 🏡 الفلل والشقق ───── */
  String? _openV;
  Future<void> _villas() => _page('🏡 الفلل والشقق', (ss) {
        final D = d!; final V = objs(D['villas']);
        Future<void> up() async { ss(() {}); await _save(); }
        return ListView(padding: const EdgeInsets.fromLTRB(10, 10, 10, 90), children: [
          for (var vi = 0; vi < V.length; vi++) Builder(builder: (_) {
            final v = V[vi]; final U = objs(v['units']); final nb = U.where((a) => truthy(a['booked'])).length; final open = _openV == v['id'];
            return Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ListTile(onTap: () => ss(() => _openV = open ? null : str(v['id'])), title: Text('🏡 ${str(v['name']).isEmpty ? 'فيلا' : v['name']}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${U.length} شقة${nb > 0 ? ' • $nb محجوزة' : ''}${truthy(v['area']) ? ' • ${v['area']}' : ''}'), trailing: Icon(open ? Icons.expand_less : Icons.expand_more)),
              if (open) ...[
                Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Wrap(spacing: 6, runSpacing: 6, children: [
                  FilledButton.tonal(onPressed: () async { await _editUnit(v, null); up(); }, child: const Text('➕ شقة')),
                  OutlinedButton(onPressed: () async { await _editVilla(v); up(); }, child: const Text('✎ الفيلا')),
                  if (truthy(v['loc'])) OutlinedButton(onPressed: () => Native.openUrl(str(v['loc'])), child: const Text('📍 اللوكيشن')),
                  if (vi > 0) OutlinedButton(onPressed: () { final L = D['villas'] as List; final x = L.removeAt(vi); L.insert(vi - 1, x); up(); }, child: const Text('⬆ فوق')),
                  OutlinedButton(onPressed: () async { if (!await confirmDlg(context, 'تلغي «${v['name']}» بكل شققها من الأبديت؟', ok: '🗑 امسح')) return; (D['villas'] as List).removeAt(vi); up(); }, child: const Text('🗑', style: TextStyle(color: kRed))),
                ])),
                if (truthy(v['note'])) Padding(padding: const EdgeInsets.fromLTRB(12, 6, 12, 0), child: Text('📝 ${v['note']}', style: const TextStyle(color: kMuted, fontSize: 12))),
                for (var ui = 0; ui < U.length; ui++) Builder(builder: (_) {
                  final a = U[ui]; final pr = Upd.cols(D).where((x) => x['mo'] != 1 && truthy((x['v'] as Function)(a))).map((x) => Upd.nf((x['v'] as Function)(a))).firstOrNull;
                  final sub = [if (truthy(a['mo'])) '${Upd.nf(a['mo'])} شهري', if (pr != null) '$pr سنوي', if (truthy(a['note'])) '📝 ${a['note']}'];
                  return Container(
                    margin: const EdgeInsets.fromLTRB(8, 6, 8, 0), padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: truthy(a['booked']) ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: kBd)),
                    child: Row(children: [
                      CircleAvatar(radius: 15, backgroundColor: _G, child: Text(str(a['no']).isEmpty ? '—' : str(a['no']), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900))),
                      const SizedBox(width: 8),
                      Expanded(child: InkWell(onTap: () async { await _editUnit(v, a); up(); }, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${Upd.typeAr(a)} • ${Upd.lab(Upd.FL, a['floor'], 1)}${truthy(a['hide']) ? ' (مخفية)' : ''}', style: TextStyle(fontWeight: FontWeight.w800, color: truthy(a['hide']) ? kMuted : kInk)),
                        if (sub.isNotEmpty) Text(sub.join(' • '), style: const TextStyle(fontSize: 11.5, color: kMuted)),
                      ]))),
                      InkWell(borderRadius: BorderRadius.circular(99), onTap: () { a['booked'] = !truthy(a['booked']); up(); toast(context, truthy(a['booked']) ? 'اتعلّمت BOOKED' : 'رجعت متاحة'); },
                        child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: truthy(a['booked']) ? const Color(0xFFFFEDD5) : const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(99)),
                          child: Text(truthy(a['booked']) ? '🔒 محجوزة' : '✅ متاحة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: truthy(a['booked']) ? const Color(0xFFC2410C) : const Color(0xFF15803D))))),
                      PopupMenuButton<String>(icon: const Icon(Icons.more_horiz), onSelected: (x) async {
                        if (x == 'ed') { await _editUnit(v, a); }
                        if (x == 'hd') { a['hide'] = !truthy(a['hide']); }
                        if (x == 'del') { if (!await confirmDlg(context, 'تلغي الشقة ${str(a['no'])} من «${v['name']}»؟', ok: '🗑 امسح')) return; (v['units'] as List).removeAt(ui); }
                        up();
                      }, itemBuilder: (_) => [
                        const PopupMenuItem(value: 'ed', child: Text('✎ عدّل الشقة')),
                        PopupMenuItem(value: 'hd', child: Text(truthy(a['hide']) ? '👁 اظهرها في الصورة' : '🙈 اخفيها من الصورة مؤقتاً')),
                        const PopupMenuItem(value: 'del', child: Text('🗑 امسح الشقة', style: TextStyle(color: kRed))),
                      ]),
                    ]),
                  );
                }),
                const SizedBox(height: 10),
              ],
            ]));
          }),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: FilledButton(onPressed: () async { await _editVilla(null); up(); }, child: const Text('➕ فيلا'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: () { D['hideBooked'] = !truthy(D['hideBooked']); up(); }, child: Text(truthy(D['hideBooked']) ? '👁 أظهر المحجوز' : '🙈 اخفي المحجوز'))),
          ]),
        ]);
      });

  Future<void> _editVilla(Map<String, dynamic>? v) async {
    final x = v ?? {};
    final o = await formDlg(context, v == null ? 'فيلا جديدة' : 'الفيلا', [
      FieldSpec('name', 'اسم الفيلا ورقمها (مثال: VILLA AL RASHED 44)', v: str(x['name'])), FieldSpec('area', 'المنطقة (مثال: Al Shamkha South)', v: str(x['area'])),
      FieldSpec('loc', 'لينك اللوكيشن (جوجل ماب ← مشاركة ← نسخ الرابط)', v: str(x['loc'])), FieldSpec('note', 'ملاحظة على الفيلا (تظهر في الصورة)', v: str(x['note'])),
    ]);
    if (o == null) return;
    if ((o['name'] ?? '').trim().isEmpty && v == null) { if (mounted) toast(context, 'اكتب اسم الفيلا'); return; }
    final t = v ?? <String, dynamic>{'id': Upd.uid(), 'units': <dynamic>[]};
    for (final k in ['name', 'area', 'loc', 'note']) { t[k] = (o[k] ?? '').trim(); }
    if (v == null) { (d!['villas'] as List).add(t); _openV = str(t['id']); }
  }

  /// شقة: كل الخانات في شاشة واحدة
  Future<void> _editUnit(Map<String, dynamic> v, Map<String, dynamic>? a0) async {
    final D = d!; final P = Upd.PM(D); final a = a0 ?? <String, dynamic>{'floor': 'G', 'type': 'st', 'furn': mode == 'f'};
    var fl = str(a['floor']).isEmpty ? 'G' : str(a['floor']), ty = str(a['type']).isEmpty ? 'st' : str(a['type']);
    var furn = truthy(a['furn']), bk = truthy(a['booked']), hd = truthy(a['hide']);
    final c = {for (final k in ['no', 'tx', 'price', 'mo', 'note', 'p1', 'p2', 'p3', 'p4']) k: TextEditingController(text: str(a[k]) == '0' ? '' : str(a[k]))};
    InputDecoration dec(String l) => InputDecoration(labelText: l, border: const OutlineInputBorder(), isDense: true);
    final n = P['n'] as int;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => Directionality(textDirection: Tr.dir, child: StatefulBuilder(builder: (ctx, ss) => AlertDialog(
      title: Text(a0 == null ? 'شقة في ${v['name']}' : 'الشقة ${str(a['no'])}'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(value: fl, decoration: dec('الدور'), items: [for (final f in Upd.FL) DropdownMenuItem(value: f[0], child: Text(f[1]))], onChanged: (x) => ss(() => fl = x!))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: c['no'], decoration: dec('رقم الشقة'))),
        ]),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(value: Upd.TY.any((t) => t[0] == ty) ? ty : 'st', decoration: dec('النوع'), items: [for (final t in Upd.TY) DropdownMenuItem(value: t[0], child: Text(t[1]))], onChanged: (x) => ss(() => ty = x!)),
        if (ty == 'x') Padding(padding: const EdgeInsets.only(top: 8), child: TextField(controller: c['tx'], decoration: dec('اكتب النوع (بالإنجليزي)'))),
        const SizedBox(height: 8),
        if (P['m'] == 'sep') for (var i = 1; i <= n; i++) Padding(padding: const EdgeInsets.only(bottom: 8), child: TextField(controller: c['p$i'], keyboardType: TextInputType.number, decoration: dec('السعر السنوي على ${i == 1 ? 'دفعة واحدة' : i == 2 ? 'دفعتين' : '$i دفعات'}')))
        else Padding(padding: const EdgeInsets.only(bottom: 8), child: TextField(controller: c['price'], keyboardType: TextInputType.number, decoration: dec(P['m'] == 'range' ? 'السعر السنوي (من دفعة لـ $n — مبلغ ثابت)' : 'السعر السنوي ($n ${n == 1 ? 'دفعة' : 'دفعات'})'))),
        TextField(controller: c['mo'], keyboardType: TextInputType.number, decoration: dec('الإيجار الشهري')),
        const SizedBox(height: 8),
        TextField(controller: c['note'], decoration: dec('ملاحظة على الشقة (تظهر في عمود الملاحظات)')),
        CheckboxListTile(contentPadding: EdgeInsets.zero, dense: true, value: furn, onChanged: (x) => ss(() => furn = x!), title: const Text('مفروشة')),
        CheckboxListTile(contentPadding: EdgeInsets.zero, dense: true, value: bk, onChanged: (x) => ss(() => bk = x!), title: const Text('محجوزة (BOOKED)')),
        CheckboxListTile(contentPadding: EdgeInsets.zero, dense: true, value: hd, onChanged: (x) => ss(() => hd = x!), title: const Text('اخفيها من الصورة مؤقتاً')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ'))],
    ))));
    if (ok != true) return;
    num nn(String k) { final x = double.tryParse(c[k]!.text.replaceAll(',', '').trim()) ?? 0; return x == x.roundToDouble() ? x.toInt() : x; }
    a['floor'] = fl; a['type'] = ty; a['no'] = c['no']!.text.trim(); a['tx'] = ty == 'x' ? c['tx']!.text.trim() : ''; a['furn'] = furn; a['booked'] = bk; a['hide'] = hd;
    a['price'] = P['m'] == 'sep' ? nn('p1') : nn('price'); for (var i = 1; i <= 4; i++) { if (P['m'] == 'sep') a['p$i'] = nn('p$i'); }
    a['mo'] = nn('mo'); a['note'] = c['note']!.text.trim();
    if (a0 == null) { a['id'] = Upd.uid(); a['at'] = DateTime.now().millisecondsSinceEpoch; ((v['units'] as List?) ?? (v['units'] = <dynamic>[])).add(a); }
  }

  /* ───── 🧱 الأعمدة ───── */
  Future<void> _colsEd() => _page('🧱 الأعمدة', (ss) {
        final D = d!; final o = _colOrder(D); final hc = _m(D, 'hc'); final names = {for (final c in _allCols(D)) c[0]: c[1]};
        Future<void> up() async { ss(() {}); await _save(); }
        return ListView(padding: const EdgeInsets.all(12), children: [
          const Text('اسحب من ⠿ لفوق أو لتحت — اللي فوق = أول عمود من الشمال في الصورة', style: TextStyle(color: kMuted, fontSize: 12)),
          const SizedBox(height: 8),
          ReorderableListView(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), buildDefaultDragHandles: false, onReorder: (a, b) { if (b > a) b--; final x = o.removeAt(a); o.insert(b, x); D['order'] = o; up(); }, children: [
            for (var i = 0; i < o.length; i++) Card(key: ValueKey(o[i]), child: ListTile(
              leading: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_indicator)),
              title: Text('${names[o[i]]}${hc[o[i]] == true ? ' (مخفي)' : ''}', style: TextStyle(color: hc[o[i]] == true ? kMuted : kInk, fontWeight: FontWeight.w700)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (o[i].startsWith('c_')) IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () async {
                  final cc = objs(D['cc']).firstWhere((c) => 'c_${c['id']}' == o[i]);
                  final r = await formDlg(context, 'اسم العمود', [FieldSpec('h', 'العنوان (بالإنجليزي)', v: str(cc['h']))]); if (r == null) return; cc['h'] = (r['h'] ?? '').trim(); up();
                }),
                TextButton(onPressed: () { if (hc[o[i]] == true) { hc.remove(o[i]); } else { hc[o[i]] = true; } up(); }, child: Text(hc[o[i]] == true ? 'أظهر' : 'اخفي')),
              ]),
            )),
          ]),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () async {
            final r = await formDlg(context, '➕ عمود جديد', [FieldSpec('h', 'عنوان العمود (بالإنجليزي) — مثال: VIEW')]);
            if (r == null || (r['h'] ?? '').trim().isEmpty) return;
            final L = (D['cc'] is List) ? D['cc'] as List : (D['cc'] = <dynamic>[]); L.add({'id': Upd.uid(), 'h': r['h']!.trim()}); up();
          }, child: const Text('➕ عمود جديد')),
          TextButton(onPressed: () { D.remove('order'); up(); }, child: const Text('↺ الترتيب الأصلي')),
        ]);
      });

  /* ───── 📞 أرقام التواصل ───── */
  Future<void> _phones() => _page('📞 أرقام التواصل', (ss) {
        final D = d!; final ph = <String>[str(D['phone']), ...lst(D['phones']).map((e) => str(e))]; final nm = lst(D['phnm']).map((e) => str(e)).toList();
        while (nm.length < ph.length) { nm.add(''); }
        Future<void> put() async { D['phone'] = ph.isEmpty ? '' : ph.first; D['phones'] = ph.skip(1).toList(); D['phnm'] = nm.take(ph.length).toList(); ss(() {}); await _save(); }
        return ListView(padding: const EdgeInsets.all(12), children: [
          const Text('الاسم اختياري (مثال: OSAMA) — كل رقم بيظهر تحت في الصورة', style: TextStyle(color: kMuted, fontSize: 12)),
          const SizedBox(height: 8),
          for (var i = 0; i < ph.length; i++) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
            Expanded(flex: 2, child: TextFormField(initialValue: nm[i], decoration: const InputDecoration(labelText: 'الاسم', border: OutlineInputBorder(), isDense: true), onChanged: (x) => nm[i] = x, onTapOutside: (_) => put())),
            const SizedBox(width: 6),
            Expanded(flex: 3, child: TextFormField(initialValue: ph[i], keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'الرقم', border: OutlineInputBorder(), isDense: true), onChanged: (x) => ph[i] = x, onTapOutside: (_) => put())),
            IconButton(icon: const Icon(Icons.close, color: kRed), onPressed: () { ph.removeAt(i); nm.removeAt(i); put(); }),
          ])),
          OutlinedButton(onPressed: () { ph.add(''); nm.add(''); ss(() {}); }, child: const Text('➕ رقم تاني')),
          const SizedBox(height: 8),
          FilledButton(onPressed: () async { FocusManager.instance.primaryFocus?.unfocus(); await put(); if (mounted) toast(context, '✅ اتحفظ'); }, child: const Text('✅ حفظ')),
        ]);
      });

  /* ───── 🔤 كلام الصورة ───── */
  Future<void> _texts() => _page('🔤 كلام الصورة', (ss) {
        final D = d!; final lab = _m(D, 'lab'); final hf = _m(D, 'hf');
        Future<void> up() async { ss(() {}); await _save(); }
        Widget f(String l, String v, ValueChanged<String> on, {bool num = false, int lines = 1}) => Padding(padding: const EdgeInsets.only(bottom: 8), child: TextFormField(initialValue: v, maxLines: lines, keyboardType: num ? TextInputType.number : null, decoration: InputDecoration(labelText: l, border: const OutlineInputBorder(), isDense: true), onChanged: on, onTapOutside: (_) => up()));
        final fx = (D['fx'] is List) ? D['fx'] as List : (D['fx'] = <dynamic>[]);
        return ListView(padding: const EdgeInsets.all(12), children: [
          f('العنوان', str(D['title']), (x) => D['title'] = x),
          DropdownButtonFormField<String>(value: ['u', 'r', 'l', 'b', 'n'].contains(D['dtpos']) ? str(D['dtpos']) : 'r', decoration: const InputDecoration(labelText: 'مكان التاريخ', border: OutlineInputBorder(), isDense: true),
            items: const [DropdownMenuItem(value: 'u', child: Text('تحت العنوان')), DropdownMenuItem(value: 'r', child: Text('فوق يمين')), DropdownMenuItem(value: 'l', child: Text('فوق شمال')), DropdownMenuItem(value: 'b', child: Text('تحت خالص')), DropdownMenuItem(value: 'n', child: Text('من غير تاريخ'))],
            onChanged: (x) { D['dtpos'] = x; up(); }),
          const SizedBox(height: 8),
          f('كلمة التاريخ', _lb(D, 'upd', 'UPDATED'), (x) => lab['upd'] = x),
          f('التأمين', str(D['dep']), (x) => D['dep'] = x),
          f('رسوم العقد (رقم)', str(D['fee']), (x) { final v = double.tryParse(x) ?? 0; D['fee'] = v == v.roundToDouble() ? v.toInt() : v; }, num: true),
          f('العمولة (فاضية = مش هتظهر)', str(D['comm']), (x) => D['comm'] = x),
          f('الكلام اللي فوق الأرقام', _lb(D, 'ct', 'BOOK YOUR VIEWING · CALL OR WHATSAPP'), (x) => lab['ct'] = x),
          f('ملاحظات تحت الجدول', str(D['notes']), (x) => D['notes'] = x, lines: 3),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: hf['fee'] != true, onChanged: (x) { if (x) { hf.remove('fee'); } else { hf['fee'] = true; } up(); }, title: const Text('خانة رسوم العقد ظاهرة')),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: hf['dep'] != true, onChanged: (x) { if (x) { hf.remove('dep'); } else { hf['dep'] = true; } up(); }, title: const Text('خانة التأمين ظاهرة')),
          const Divider(),
          const Text('خانات بتظهر تحت الجدول جنب التأمين (مثال: PARKING — FREE)', style: TextStyle(color: kMuted, fontSize: 12)),
          const SizedBox(height: 6),
          for (var i = 0; i < fx.length; i++) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
            Expanded(child: TextFormField(initialValue: str(obj(fx[i])?['h']), decoration: const InputDecoration(labelText: 'العنوان', border: OutlineInputBorder(), isDense: true), onChanged: (x) => obj(fx[i])!['h'] = x, onTapOutside: (_) => up())),
            const SizedBox(width: 6),
            Expanded(child: TextFormField(initialValue: str(obj(fx[i])?['v']), decoration: const InputDecoration(labelText: 'القيمة', border: OutlineInputBorder(), isDense: true), onChanged: (x) => obj(fx[i])!['v'] = x, onTapOutside: (_) => up())),
            IconButton(icon: const Icon(Icons.close, color: kRed), onPressed: () { fx.removeAt(i); up(); }),
          ])),
          OutlinedButton(onPressed: () { fx.add({'h': '', 'v': ''}); ss(() {}); }, child: const Text('➕ خانة')),
        ]);
      });

  /* ───── ⚙️ الأسعار والدفعات ───── */
  Future<void> _prices() => _page('⚙️ الأسعار والدفعات', (ss) {
        final D = d!; final P = Upd.PM(D);
        Future<void> up() async { ss(() {}); await _save(); }
        return ListView(padding: const EdgeInsets.all(12), children: [
          const Text('💳 نظام الدفعات في الصورة', style: TextStyle(fontWeight: FontWeight.w900)),
          for (final o in const [['sep', 'عمود لكل عدد دفعات (دفعة / دفعتين / 3 دفعات… كل واحد بسعره)'], ['range', 'عمود واحد: من دفعة لحد كذا دفعة بسعر ثابت'], ['single', 'عمود واحد: عدد دفعات محدد بسعر ثابت']])
            RadioListTile<String>(contentPadding: EdgeInsets.zero, value: o[0], groupValue: P['m'] as String, onChanged: (x) { D['pm'] = x; up(); }, title: Text(o[1], style: const TextStyle(fontSize: 13.5))),
          const SizedBox(height: 6),
          const Text('عدد الدفعات', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          SegmentedButton<int>(segments: [for (var i = 1; i <= 4; i++) ButtonSegment(value: i, label: Text('$i'))], selected: {P['n'] as int}, onSelectionChanged: (s) { D['pn'] = s.first; up(); }),
          const SizedBox(height: 8),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: D['showMo'] != false, onChanged: (x) { D['showMo'] = x; up(); }, title: const Text('عمود الإيجار الشهري')),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: D['showNote'] != false, onChanged: (x) { D['showNote'] = x; up(); }, title: const Text('عمود الملاحظات')),
        ]);
      });

  /* ───── 📊 تعديل حر (زي الإكسيل) ───── */
  Future<void> _grid() => _page('📊 تعديل حر', (ss) {
        final D = d!; final P = Upd.PM(D);
        Future<void> up() async { await _save(); }
        Widget cell(Map a, String k, {double w = 90, bool num = false}) => SizedBox(width: w, child: TextFormField(
              initialValue: str(a[k]) == '0' ? '' : str(a[k]), keyboardType: num ? TextInputType.number : null, style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8)),
              onChanged: (x) { if (num) { final v = double.tryParse(x.replaceAll(',', '')) ?? 0; a[k] = v == v.roundToDouble() ? v.toInt() : v; } else { a[k] = x; } }, onTapOutside: (_) => up()));
        Widget hd(String t, double w) => SizedBox(width: w, child: Text(t, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)));
        return ListView(padding: const EdgeInsets.all(10), children: [
          if (objs(D['villas']).isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('ضيف فيلا الأول')),
          for (final v in objs(D['villas'])) Card(child: Padding(padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('🏡 ${v['name']}', style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [hd('شقة', 60), hd('الدور', 80), hd('النوع', 110), if (P['m'] == 'sep') for (var i = 1; i <= (P['n'] as int); i++) hd('$i دفعة', 90) else hd('السنوي', 90), hd('الشهري', 80), hd('ملاحظة', 120), hd('الحالة', 90)].expand((w) => [w, const SizedBox(width: 4)]).toList()),
              const SizedBox(height: 4),
              for (final a in objs(v['units'])) Padding(padding: const EdgeInsets.only(bottom: 4), child: StatefulBuilder(builder: (_, rs) => Row(children: [
                cell(a, 'no', w: 60),
                SizedBox(width: 80, child: DropdownButton<String>(isExpanded: true, value: Upd.FL.any((f) => f[0] == a['floor']) ? str(a['floor']) : 'G', items: [for (final f in Upd.FL) DropdownMenuItem(value: f[0], child: Text(f[1], style: const TextStyle(fontSize: 13)))], onChanged: (x) { a['floor'] = x; rs(() {}); up(); })),
                SizedBox(width: 110, child: DropdownButton<String>(isExpanded: true, value: Upd.TY.any((t) => t[0] == a['type']) ? str(a['type']) : 'st', items: [for (final t in Upd.TY) DropdownMenuItem(value: t[0], child: Text(t[1], style: const TextStyle(fontSize: 13)))], onChanged: (x) { a['type'] = x; rs(() {}); up(); })),
                if (P['m'] == 'sep') for (var i = 1; i <= (P['n'] as int); i++) cell(a, i == 1 && !truthy(a['p1']) ? 'price' : 'p$i', num: true) else cell(a, 'price', num: true),
                cell(a, 'mo', w: 80, num: true),
                cell(a, 'note', w: 120),
                SizedBox(width: 90, child: TextButton(onPressed: () { a['booked'] = !truthy(a['booked']); rs(() {}); up(); }, child: Text(truthy(a['booked']) ? '🔒 محجوزة' : '✅ متاحة', style: const TextStyle(fontSize: 12)))),
              ].expand((w) => [w, const SizedBox(width: 4)]).toList()))),
            ])),
            TextButton(onPressed: () { ((v['units'] as List?) ?? (v['units'] = <dynamic>[])).add({'id': Upd.uid(), 'at': DateTime.now().millisecondsSinceEpoch, 'floor': 'G', 'type': 'st', 'no': '', 'furn': mode == 'f', 'price': 0, 'mo': 0, 'note': '', 'booked': false}); ss(() {}); up(); }, child: Text('➕ شقة جديدة في ${v['name']}')),
          ]))),
        ]);
      });

  /* ───── 👥 الجروب ───── */
  Future<void> _group() async {
    final D = d!;
    final o = await formDlg(context, '👥 جروب الواتساب', [
      FieldSpec('gname', 'اسم الجروب بالظبط زي ما هو مكتوب في واتساب', v: str(D['gname'])),
      FieldSpec('group', 'لينك دعوة الجروب (اختياري) — من معلومات الجروب ← الدعوة عبر رابط', v: str(D['group'])),
    ]);
    if (o == null) return;
    D['gname'] = (o['gname'] ?? '').trim(); D['group'] = (o['group'] ?? '').trim(); await _save('✅ اتحفظ الجروب');
  }

  /* ───── الصورة ───── */
  Future<Uint8List?> _png() async {
    if (!prev) { setState(() => prev = true); await Future.delayed(const Duration(milliseconds: 350)); }
    final b = key.currentContext?.findRenderObject() as RenderRepaintBoundary?; if (b == null) return null;
    final img = await b.toImage(pixelRatio: 2); final bd = await img.toByteData(format: ui.ImageByteFormat.png);
    return bd?.buffer.asUint8List();
  }
  Future<void> _shareImg() async {
    try {
      final p = await _png(); if (p == null) return;
      final D = d!; final name = 'update_${DateTime.now().millisecondsSinceEpoch}.png';
      if (truthy(D['gname'])) { await Clipboard.setData(ClipboardData(text: str(D['gname']))); if (mounted) toast(context, 'اختار الجروب «${D['gname']}» من قايمة المشاركة'); }
      await Share.shareXFiles([XFile.fromData(p, mimeType: 'image/png', name: name)], text: str(D['title']));
    } catch (e) { if (mounted) toast(context, '⚠️ $e'); }
  }
  Future<void> _saveImg() async {
    try { final p = await _png(); if (p == null) return; await Share.shareXFiles([XFile.fromData(p, mimeType: 'image/png', name: 'update.png')]); } catch (e) { if (mounted) toast(context, '⚠️ $e'); }
  }
}

/* ═══════════ صورة الأبديت — نفس شكل القديم ═══════════ */
class UpdPoster extends StatelessWidget {
  final Map d; final String mode;
  const UpdPoster(this.d, this.mode, {super.key});
  static const _mn = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
  static const _flS = {'G': 'G', '1': '1ST', '2': '2ND', '3': '3RD', 'R': 'ROOF'};

  @override
  Widget build(BuildContext context) {
    final P = Upd.PM(d); final hc = obj(d['hc']) ?? {}; final hf = obj(d['hf']) ?? {};
    final L = objs(d['villas']).where((v) => objs(v['units']).any((a) => Upd.shown(d, a))).toList();
    final all = [for (final v in L) ...objs(v['units']).where((a) => Upd.shown(d, a))];
    final C = Upd.cols(d).where((x) => x['mo'] != 1 || all.any((a) => n0(a['mo']) > 0)).toList();
    final CP = C.where((x) => x['mo'] != 1).toList(), CM = C.where((x) => x['mo'] == 1).toList();
    final flt = all.any((a) => str(a['no']).trim().isNotEmpty), nt = d['showNote'] != false && all.any((a) => str(a['note']).trim().isNotEmpty);
    final K = _colOrder(d).where((k) => hc[k] != true && (k.startsWith('c_') || (k == 'fn' ? flt : k == 'nt' ? nt : k == 'pay' ? CP.isNotEmpty : k == 'mo' ? CM.isNotEmpty : true))).toList();
    final now = DateTime.now(); final dt = '${now.day.toString().padLeft(2, '0')} ${_mn[now.month - 1]} ${now.year}';
    final dp = ['u', 'r', 'l', 'b', 'n'].contains(d['dtpos']) ? str(d['dtpos']) : 'r';
    final dth = Text('${_lb(d, 'upd', 'UPDATED')} · $dt', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF6B7F75), letterSpacing: 1.5));
    final ph = Upd.phl(d);
    bool isNew(Map a) => !truthy(a['booked']) && n0(a['at']) > 0 && now.millisecondsSinceEpoch - n0(a['at']) < 3 * 864e5;
    final allNew = all.where((a) => !truthy(a['booked'])).length > 1 && all.where((a) => !truthy(a['booked'])).every(isNew);

    // عرض الأعمدة (نسب)
    double wOf(String k) => const {'fl': 15.0, 'fn': 9.0, 'nt': 17.0}[k] ?? (k == 'ty' ? (flt ? 23.0 : 28.0) : k.startsWith('c_') ? 14.0 : 0);
    final fix = K.fold<double>(0, (s, k) => s + wOf(k)); final each = (100 - fix) / math.max(1, C.length);
    final widths = <double>[for (final k in K) ...(k == 'pay' ? CP.map((_) => each) : k == 'mo' ? CM.map((_) => each) : [wOf(k)])];
    const hs = TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _G, letterSpacing: 1.6);

    Widget hdCell(String k, [Map? x]) {
      if (k.startsWith('c_')) { final cc = objs(d['cc']).where((c) => 'c_${c['id']}' == k).firstOrNull; return Text(str(cc?['h']).toUpperCase(), textAlign: TextAlign.center, style: hs); }
      if (k == 'fl') return Text(_lb(d, 'fl', 'FLOOR'), textAlign: TextAlign.center, style: hs);
      if (k == 'fn') return Text(_lb(d, 'fn', 'FLAT'), textAlign: TextAlign.center, style: hs);
      if (k == 'ty') return Text(_lb(d, 'ty', 'TYPE'), textAlign: TextAlign.center, style: hs);
      if (k == 'nt') return Text(_lb(d, 'nt', 'NOTES'), textAlign: TextAlign.center, style: hs);
      if (x!['mo'] == 1) return Column(children: [Text(_lb(d, 'mo', 'MONTHLY'), textAlign: TextAlign.center, style: hs), if (str(obj(d['lab'])?['mo']).isEmpty) const Text('AED / MONTH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _G2))]);
      if (P['m'] == 'sep') return Text(str(x['h']), textAlign: TextAlign.center, style: hs);
      return Column(children: [Text(_lb(d, 'pay', 'RENT / YEAR'), textAlign: TextAlign.center, style: hs), if (str(obj(d['lab'])?['pay']).isEmpty) Text(str(x['h']), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _G2))]);
    }

    Widget money(num v, bool bk) => v == 0 ? const Text('—', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, color: Color(0xFFB0B8B4)))
        : Column(mainAxisSize: MainAxisSize.min, children: [Text(Upd.nf(v), style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900, color: bk ? const Color(0xFF9AA5A0) : _RD)), Text('AED', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2, color: bk ? const Color(0xFF9AA5A0) : _RD.withOpacity(.85)))]);

    List<Widget> rowCells(Map a) {
      final bk = truthy(a['booked']); final out = <Widget>[]; var skip = 0;
      for (var ki = 0; ki < K.length; ki++) {
        final k = K[ki];
        if (k.startsWith('c_')) { out.add(Text(str(a[k]), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _G))); continue; }
        if (k == 'fl') { out.add(Column(mainAxisSize: MainAxisSize.min, children: [Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFEEF2EF), borderRadius: BorderRadius.circular(8)), child: Text(_flS[a['floor']] ?? Upd.lab(Upd.FL, a['floor'], 2), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _G))), if (a['floor'] != 'R') const Padding(padding: EdgeInsets.only(top: 4), child: Text('FLOOR', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2, color: _G)))])); continue; }
        if (k == 'fn') { out.add(Center(child: Container(width: 50, height: 50, alignment: Alignment.center, decoration: const BoxDecoration(color: _G, shape: BoxShape.circle), child: Text(str(a['no']).isEmpty ? '—' : str(a['no']), style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900))))); continue; }
        if (k == 'ty') { out.add(Column(mainAxisSize: MainAxisSize.min, children: [Text(Upd.typeEn(a), textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: .8, color: bk ? const Color(0xFF8A938F) : _RD)), if (!allNew && isNew(a)) Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(6)), child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)))])); continue; }
        if (k == 'nt') { out.add(Text(str(a['note']), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1F2D27)))); continue; }
        final L2 = k == 'pay' ? CP : CM;
        if (bk) {
          if (skip > 0) { skip--; for (var i = 0; i < L2.length; i++) { out.add(const SizedBox()); } continue; }
          out.add(Center(child: Transform.rotate(angle: -.05, child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6), decoration: BoxDecoration(border: Border.all(color: _RD, width: 2.5), borderRadius: BorderRadius.circular(8)), child: const Text('BOOKED', style: TextStyle(color: _RD, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 5))))));
          for (var i = 1; i < L2.length; i++) { out.add(const SizedBox()); }
          final nx = ki + 1 < K.length ? K[ki + 1] : ''; if (nx == 'pay' || nx == 'mo') skip = 1;
          continue;
        }
        for (final x in L2) { out.add(money(n0((x['v'] as Function)(a)), bk)); }
      }
      return out;
    }

    final cw = {for (var i = 0; i < widths.length; i++) i: FlexColumnWidth(widths[i])};
    return Container(
      width: 900, color: Colors.white, padding: const EdgeInsets.fromLTRB(26, 22, 26, 26),
      child: Directionality(textDirection: TextDirection.ltr, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (dp == 'r') Align(alignment: Alignment.centerRight, child: dth),
        if (dp == 'l') Align(alignment: Alignment.centerLeft, child: dth),
        Text(str(d['title']).isEmpty ? 'AVAILABLE UNITS' : str(d['title']).toUpperCase(), style: const TextStyle(fontSize: 58, fontWeight: FontWeight.w900, color: _G, letterSpacing: 2, height: 1.1)),
        const SizedBox(height: 10),
        Row(children: [Container(width: 60, height: 2, color: _G2), const SizedBox(width: 10), if (dp == 'u') dth else Transform.rotate(angle: .785, child: Container(width: 10, height: 10, color: _G2)), const SizedBox(width: 10), Container(width: 60, height: 2, color: _G2)]),
        const SizedBox(height: 22),
        for (final v in L) Container(
          margin: const EdgeInsets.only(bottom: 18), clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFDCE3DF), width: 1.5)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(padding: const EdgeInsets.fromLTRB(26, 22, 26, 18), child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(width: 5, color: _G2), const SizedBox(width: 20),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(str(v['name']).toUpperCase(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: _G, letterSpacing: 1)),
                if (truthy(v['area'])) Text('📍 ${v['area']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1F2D27))),
                if (truthy(v['note'])) Text(str(v['note']), style: const TextStyle(fontSize: 19, color: Color(0xFF52615A))),
              ])),
            ]))),
            Table(columnWidths: cw, defaultVerticalAlignment: TableCellVerticalAlignment.middle, children: [
              TableRow(decoration: const BoxDecoration(color: Color(0xFFEEF3F0)), children: [for (final k in K) ...(k == 'pay' ? CP.map((x) => Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: hdCell(k, x))) : k == 'mo' ? CM.map((x) => Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: hdCell(k, x))) : [Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: hdCell(k))])]),
              for (final a in objs(v['units']).where((a) => Upd.shown(d, a)))
                TableRow(decoration: BoxDecoration(color: truthy(a['booked']) ? const Color(0xFFF5F6F5) : Colors.white, border: const Border(top: BorderSide(color: Color(0xFFE6ECE8), width: 1.2))), children: [for (final w in rowCells(a)) Padding(padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 6), child: w)]),
            ]),
          ]),
        ),
        if (L.isEmpty) const Padding(padding: EdgeInsets.all(40), child: Text('Add villas and flats to show them here', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, color: kMuted))),
        Row(children: [
          for (final f in [if (hf['fee'] != true) [_lb(d, 'fee', 'CONTRACT FEE'), '${Upd.nf(d['fee']).isEmpty ? '0' : Upd.nf(d['fee'])} AED'], if (hf['dep'] != true) [_lb(d, 'dep', 'SECURITY DEPOSIT'), str(d['dep'])], if (truthy(d['comm'])) [_lb(d, 'comm', 'COMMISSION'), str(d['comm'])], for (final x in objs(d['fx'])) if (truthy(x['h']) || truthy(x['v'])) [str(x['h']), str(x['v'])]])
            Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 6), padding: const EdgeInsets.symmetric(vertical: 18), decoration: BoxDecoration(color: const Color(0xFFF3F6F4), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFDCE3DF))),
              child: Column(children: [Text(f[0].toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 2, color: Color(0xFF2F3E37))), const SizedBox(height: 4), Text(f[1], textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _G))]))),
        ]),
        if (truthy(d['notes'])) Padding(padding: const EdgeInsets.only(top: 14), child: Text(str(d['notes']), textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Color(0xFF2F3E37)))),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20), decoration: BoxDecoration(color: _G, borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            Container(width: 76, height: 76, decoration: BoxDecoration(color: const Color(0xFF25D366), shape: BoxShape.circle, border: Border.all(color: const Color(0xFF1B5E3F), width: 5)), child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 36)),
            const SizedBox(width: 20),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_lb(d, 'ct', 'BOOK YOUR VIEWING · CALL OR WHATSAPP'), style: const TextStyle(color: Color(0xFFD7EBE0), fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 2)),
              const SizedBox(height: 4),
              if (ph.length <= 1) Text(ph.isEmpty ? '' : ph.first['p']!, style: const TextStyle(color: Colors.white, fontSize: 46, fontWeight: FontWeight.w900, letterSpacing: 2))
              else Wrap(spacing: 26, runSpacing: 6, children: [for (final x in ph) Text('${x['n']!.isEmpty ? '' : '${x['n']}  '}${x['p']}', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 1.5))]),
            ])),
          ]),
        ),
        if (dp == 'b') Padding(padding: const EdgeInsets.only(top: 12), child: Center(child: dth)),
      ])),
    );
  }
}
