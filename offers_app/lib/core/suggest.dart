/// اقتراحات (كلها بتستنى موافقتك):
/// 🎬 فيديوهات جديدة اتصورت جنب فيلا → اربطها بشققها
/// 📍 لينك لوكيشن اتبعت في جروب الشركة → حطه للفيلا
/// 📣 شقق جديدة ليها فيديو → بوست انستجرام جاهز
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:photo_manager/photo_manager.dart';
import 'auto.dart';
import 'model.dart';
import 'native.dart';
import 'store.dart';

class Geo {
  static List<double>? parse(String s) {
    s = Uri.decodeFull(s);
    for (final r in [RegExp(r'@(-?\d{1,3}\.\d+),\s*(-?\d{1,3}\.\d+)'), RegExp(r'[?&](?:q|ll|query|center|destination)=(-?\d{1,3}\.\d+),\s*\+?(-?\d{1,3}\.\d+)'), RegExp(r'!3d(-?\d{1,3}\.\d+)!4d(-?\d{1,3}\.\d+)'), RegExp(r'search/(-?\d{1,3}\.\d+),\s*\+?(-?\d{1,3}\.\d+)')]) {
      final m = r.firstMatch(s);
      if (m != null) { final a = double.parse(m.group(1)!), b = double.parse(m.group(2)!); if (a.abs() <= 90 && b.abs() <= 180) return [a, b]; }
    }
    return null;
  }

  /// لينك جوجل ماب (حتى المختصر goo.gl) → [lat, lng]
  static Future<List<double>?> resolve(String url) async {
    final d = parse(url);
    if (d != null) return d;
    if (kIsWeb) return null;
    var u = url.trim();
    final c = http.Client();
    try {
      for (var i = 0; i < 6; i++) {
        final rq = http.Request('GET', Uri.parse(u))..followRedirects = false..headers['User-Agent'] = 'Mozilla/5.0 (Linux; Android 14)';
        final r = await c.send(rq).timeout(const Duration(seconds: 12));
        final loc = r.headers['location'];
        if (loc != null && r.statusCode >= 300 && r.statusCode < 400) {
          u = Uri.parse(u).resolve(loc).toString();
          final p = parse(u);
          if (p != null) return p;
          continue;
        }
        final body = await r.stream.bytesToString();
        return parse(body);
      }
    } catch (_) {} finally { c.close(); }
    return null;
  }

  static double dist(List<double> a, List<double> b) {
    const R = 6371000.0;
    double rad(double x) => x * math.pi / 180;
    final dl = rad(b[0] - a[0]), dn = rad(b[1] - a[1]);
    final h = math.pow(math.sin(dl / 2), 2) + math.cos(rad(a[0])) * math.cos(rad(b[0])) * math.pow(math.sin(dn / 2), 2);
    return 2 * R * math.asin(math.sqrt(h.toDouble()));
  }

  static List<double>? of(Obj v) { final l = v['ll']; return l is List && l.length == 2 ? [numOf(l[0]), numOf(l[1])] : null; }

  /// يحسب إحداثيات كل فيلا ليها لينك ومعندهاش إحداثيات
  static Future<void> fillVillas() async {
    var ch = false;
    for (final v in Store.I.villas) {
      if (str(v['loc']).isEmpty || (of(v) != null && v['llOf'] == v['loc'])) continue;
      final p = await resolve(str(v['loc']));
      if (p != null) { v['ll'] = p; v['llOf'] = v['loc']; ch = true; }
    }
    if (ch) await Store.I.save();
  }
}

class Sug {
  // ===== 📍 لوكيشن من الجروبات =====
  static List<Obj> get locs => objs(Store.I.D['locSug']);

  static Future<void> pullLocs() async {
    if (kIsWeb || Store.I.testMode) return;
    List items;
    try { items = jsonDecode(await Native.ch.invokeMethod<String>('locTake') ?? '[]') as List; } catch (_) { return; }
    if (items.isEmpty) return;
    final l = (Store.I.D['locSug'] as List?) ?? (Store.I.D['locSug'] = <dynamic>[]);
    for (final m in items.whereType<Map>()) {
      if (l.any((x) => (x as Map)['url'] == m['url'])) continue;
      l.insert(0, {'id': uid(), 'g': str(m['g']), 'url': str(m['url']), 'txt': str(m['txt']), 'at': DateTime.fromMillisecondsSinceEpoch((m['t'] as num?)?.toInt() ?? 0).toIso8601String()});
    }
    while (l.length > 100) { l.removeLast(); }
    await Store.I.save();
  }

  /// الفيلا اللي اللينك ده غالباً بتاعها (من رقم الفيلا في الرسالة + شركة الجروب)
  static Obj? villaFor(Obj s) {
    final no = villaNoOf(str(s['txt']).replaceAll(str(s['url']), ''));
    if (no.isNotEmpty) { final v = findVilla(AutoUpd.companyOf(str(s['g'])), {'villa': 'villa $no'}, create: false); if (v != null) return v; }
    return villaByTime(s);
  }

  /// لينك اتبعت لوحده في الجروب: غالباً بتاع الأبديت اللي نزل قبله/بعده بشوية من نفس الجروب (لو كان لفيلا واحدة)
  static Obj? villaByTime(Obj s) {
    final t = DateTime.tryParse(str(s['at']));
    if (t == null) return null;
    final g = AutoUpd.cleanGroup(str(s['g']));
    final near = AutoUpd.log.where((l) {
      final lt = DateTime.tryParse(str(l['at']));
      return AutoUpd.cleanGroup(str(l['g'])) == g && str(l['vid']).isNotEmpty && lt != null && lt.difference(t).inMinutes.abs() <= 20;
    }).map((l) => str(l['vid'])).toSet();
    return near.length == 1 ? Store.I.villa(near.first) : null;
  }

  /// 📍 اللوكيشن اللي في الجروبات بيتحط لوحده للفيلا لو معروفة ومعندهاش لوكيشن — والباقي يفضل اقتراح
  static Future<List<String>> autoLocs() async {
    final out = <String>[];
    for (final s in locs.where((s) => s['st'] == null)) {
      final v = villaFor(s);
      if (v == null || str(v['loc']).isNotEmpty) continue;
      v['loc'] = s['url']; v.remove('ll'); s['st'] = 'auto';
      out.add('📍 ${str(v['name'])} ${str(v['no'])}: اتحط اللوكيشن من ${str(s['g'])}');
    }
    if (out.isNotEmpty) {
      final l = (Store.I.D['log'] as List?) ?? (Store.I.D['log'] = <dynamic>[]);
      for (final m in out) { l.insert(0, {'at': DateTime.now().toIso8601String(), 'g': '', 'm': m, 'same': true}); }
      await Store.I.save();
      Geo.fillVillas();
    }
    return out;
  }

  /// اقتراحات اللوكيشن اللي لسه متعملهاش حاجة، ولفيلا ملهاش لوكيشن (أو مش معروفة)
  static List<Obj> openLocs() => locs.where((s) { if (s['st'] != null) return false; final v = villaFor(s); return v == null || str(v['loc']).isEmpty; }).toList();

  static Future<void> applyLoc(Obj s, Obj v) async {
    v['loc'] = s['url'];
    v.remove('ll');
    s['st'] = 'ok';
    await Store.I.save();
    Geo.fillVillas();
  }

  // ===== 🎬 فيديوهات جديدة =====
  static Set<String> get linked => {for (final v in Store.I.villas) for (final u in objs(v['units'])) ...((u['videos'] as List?) ?? []).map(str)};
  static Set<String> get skipped => ((Store.I.D['vidSkip'] as List?) ?? []).map(str).toSet();

  /// فيديوهات آخر 30 يوم مش مربوطة، وكل واحد أقرب فيلا ليه (من مكان التصوير)
  static Future<List<Map<String, dynamic>>> newVideos() async {
    if (kIsWeb || Store.I.testMode) return [];
    final p = await PhotoManager.requestPermissionExtend(requestOption: const PermissionRequestOption(androidPermission: AndroidPermission(type: RequestType.video, mediaLocation: true)));
    if (!p.isAuth && !p.hasAccess) return [];
    await Geo.fillVillas();
    final since = DateTime.now().subtract(const Duration(days: 30));
    final paths = await PhotoManager.getAssetPathList(type: RequestType.video, onlyAll: true, filterOption: FilterOptionGroup(createTimeCond: DateTimeCond(min: since, max: DateTime.now().add(const Duration(days: 1)))));
    if (paths.isEmpty) return [];
    final n = await paths.first.assetCountAsync;
    final list = await paths.first.getAssetListRange(start: 0, end: math.min(n, 300));
    final lk = linked, sk = skipped;
    final vs = Store.I.villas.where((v) => Geo.of(v) != null).toList();
    final out = <Map<String, dynamic>>[];
    for (final a in list) {
      if (lk.contains(a.id) || sk.contains(a.id)) continue;
      Obj? best; var bd = 1e12;
      try {
        final ll = await a.latlngAsync();
        if (ll != null && (ll.latitude != 0 || ll.longitude != 0)) {
          for (final v in vs) { final d = Geo.dist([ll.latitude, ll.longitude], Geo.of(v)!); if (d < bd) { bd = d; best = v; } }
        }
      } catch (_) {}
      out.add({'a': a, 'v': bd <= 300 ? best : null, 'd': bd, 'u': null});
    }
    return out;
  }

  static Future<void> link(Obj u, String assetId) async {
    final l = (u['videos'] as List?) ?? (u['videos'] = <dynamic>[]);
    if (!l.contains(assetId)) l.add(assetId);
    await Store.I.save();
  }

  static Future<void> skip(String id) async {
    final l = (Store.I.D['vidSkip'] as List?) ?? (Store.I.D['vidSkip'] = <dynamic>[]);
    if (!l.contains(id)) l.add(id);
    while (l.length > 2000) { l.removeAt(0); }
    await Store.I.save();
  }

  // ===== 📣 بوستات انستجرام =====
  static Set<String> get postedOrSkipped => ((Store.I.D['posted'] as List?) ?? []).map(str).toSet();

  /// شقق نزلت/رجعت متاحة آخر 10 أيام وليها فيديو ولسه متنشرتش
  static List<Map<String, dynamic>> posts() {
    final done = postedOrSkipped, lim = DateTime.now().subtract(const Duration(days: 10));
    final out = <Map<String, dynamic>>[];
    for (final v in Store.I.villas) {
      for (final u in objs(v['units'])) {
        final at = DateTime.tryParse(str(u['newAt']));
        if (u['avail'] == false || at == null || at.isBefore(lim) || ((u['videos'] as List?) ?? []).isEmpty) continue;
        final k = '${v['id']}/${u['id']}/${str(u['newAt'])}';
        if (done.contains(k)) continue;
        out.add({'v': v, 'u': u, 'k': k});
      }
    }
    return out;
  }

  static String caption(Obj v, Obj u) {
    final en = kTypesEn[str(u['type'])] ?? 'Apartment';
    final p1 = Price.p1(u), p3 = Price.p3(u), mo = Price.mo(u);
    final pr = <String>[
      if (mo > 0) '💰 ${money(mo)} درهم شهرياً | AED ${money(mo)} / month',
      if (p1 > 0) '💰 ${money(p1)} درهم سنوياً (دفعة واحدة) | AED ${money(p1)} / year (1 payment)',
      if (Price.p2(u) > 0 && p1 <= 0) '💰 ${money(Price.p2(u))} درهم سنوياً (دفعتين) | AED ${money(Price.p2(u))} / year (2 payments)',
      if (p3 > 0 && p1 <= 0 && Price.p2(u) <= 0) '💰 ${money(p3)} درهم سنوياً (3 دفعات) | AED ${money(p3)} / year (3 payments)',
    ];
    final area = str(v['area']);
    final ph = str(Store.I.cfg['myPhone']);
    return [
      '✨ متاح الآن | Available Now',
      '🏠 ${typeName(u['type'])} | $en',
      if (area.isNotEmpty) '📍 $area',
      ...pr,
      ph.isNotEmpty ? '📲 واتساب | WhatsApp: +$ph' : '📲 راسلنا واتساب | DM us on WhatsApp',
      '',
      '#أبوظبي #شقق_للايجار #ايجار #abudhabi #flatsforrent #rent #uae${area.isEmpty ? '' : ' #${area.replaceAll(' ', '_')}'}',
    ].join('\n');
  }

  static Future<void> markPost(String k) async {
    final l = (Store.I.D['posted'] as List?) ?? (Store.I.D['posted'] = <dynamic>[]);
    if (!l.contains(k)) l.add(k);
    while (l.length > 1000) { l.removeAt(0); }
    await Store.I.save();
  }

  static int count() => openLocs().length + posts().length;
}
