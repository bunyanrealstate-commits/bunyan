/// تذكيراتي: نفس بيانات القديم (S.rem) + إشعارات على الموبايل
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzd;
import 'package:timezone/timezone.dart' as tz;
import 'js.dart';
import 'store.dart';

class Rem {
  static final _n = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static const rpl = {'once': 'مرة واحدة', 'day': 'كل يوم', 'week': 'كل أسبوع', 'month': 'كل شهر', 'year': 'كل سنة'};

  /// زي nextAt في القديم
  static int nextAt(Obj r, [int? from]) {
    final p = str(r['d']).split('-'); final h = (str(r['tm']).isEmpty ? '09:00' : str(r['tm'])).split(':');
    var t = DateTime(int.tryParse(p[0]) ?? 2026, p.length > 1 ? (int.tryParse(p[1]) ?? 1) : 1, p.length > 2 ? (int.tryParse(p[2]) ?? 1) : 1, int.tryParse(h[0]) ?? 0, h.length > 1 ? (int.tryParse(h[1]) ?? 0) : 0);
    final f = from ?? DateTime.now().millisecondsSinceEpoch;
    if (r['rp'] == 'once') return t.millisecondsSinceEpoch;
    var g = 0;
    while (t.millisecondsSinceEpoch <= f && g++ < 4000) {
      switch (r['rp']) {
        case 'day': t = DateTime(t.year, t.month, t.day + 1, t.hour, t.minute); break;
        case 'week': t = DateTime(t.year, t.month, t.day + 7, t.hour, t.minute); break;
        case 'month': t = DateTime(t.year, t.month + 1, t.day, t.hour, t.minute); break;
        case 'year': t = DateTime(t.year + 1, t.month, t.day, t.hour, t.minute); break;
        default: g = 9999;
      }
    }
    return t.millisecondsSinceEpoch;
  }

  static Future<void> init() async {
    if (kIsWeb || _ready) return;
    tzd.initializeTimeZones();
    try { tz.setLocalLocation(tz.getLocation('Asia/Dubai')); } catch (_) {}
    await _n.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    final a = _n.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await a?.requestNotificationsPermission();
    await a?.requestExactAlarmsPermission();
    _ready = true;
  }

  /// نعيد جدولة كل التذكيرات الشغالة (لحد 60 جاية)
  /// لو بنيان القديم لسه متسطّب، هو اللي بيرن (علشان التذكير ميجيش مرتين)
  static Future<bool> oldInstalled() async { try { return await const MethodChannel('bny/link').invokeMethod<bool>('hasOld') ?? false; } catch (_) { return false; } }

  static Future<int> schedule() async {
    if (kIsWeb) return 0;
    await init();
    await _n.cancelAll();
    if (await oldInstalled()) return 0;
    final now = DateTime.now().millisecondsSinceEpoch; var k = 0;
    const det = NotificationDetails(android: AndroidNotificationDetails('bny_rem', 'تذكيراتي', channelDescription: 'تذكيرات بنيان', importance: Importance.max, priority: Priority.high, playSound: true, enableVibration: true));
    for (final r in objs(Store.I.S['rem'])) {
      if (r['on'] == false) continue;
      var at = nextAt(r);
      for (var rep = 0; rep < (r['rp'] == 'once' ? 1 : 3) && k < 60; rep++) {
        if (at > now) {
          try {
            await _n.zonedSchedule(k++, '⏰ ${str(r['t'])}', str(r['n']).isEmpty ? 'تذكير من بنيان' : str(r['n']),
              tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, at), det, androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime);
          } catch (_) {
            try { await _n.zonedSchedule(k++, '⏰ ${str(r['t'])}', str(r['n']), tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, at), det, androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime); } catch (_) {}
          }
        }
        if (r['rp'] == 'once') break;
        at = nextAt(r, at);
      }
    }
    return k;
  }

  static Future<void> test() async {
    await init();
    await _n.show(999, '🔔 تجربة', 'التذكيرات شغالة ✅', const NotificationDetails(android: AndroidNotificationDetails('bny_rem', 'تذكيراتي', importance: Importance.max, priority: Priority.high)));
  }
}
