import 'package:flutter/material.dart';
import '../core/media.dart';
import '../core/model.dart';
import '../core/native.dart';
import 'theme.dart';

/// طابور الإرسال: كل شقة رسالة لوحدها (الفيديو وتحته السعر واللوكيشن) — إنت اللي بتدوس إرسال في الواتساب
class SendQ extends ChangeNotifier {
  static final I = SendQ._();
  SendQ._();
  List<Map<String, dynamic>> jobs = [];
  int done = 0;
  Map<String, String> client = {};
  VoidCallback? onDone;

  bool get active => jobs.isNotEmpty && done < jobs.length;

  Future<void> start(BuildContext context, Map<String, String> c, List<Map<String, dynamic>> picks, String pay, {bool terms = false, VoidCallback? whenDone}) async {
    final j = <Map<String, dynamic>>[];
    for (final x in picks) {
      final v = x['v'] as Obj, u = x['u'] as Obj;
      final uris = <String>[];
      for (final id in (u['videos'] as List?)?.map(str) ?? const <String>[]) { final r = await Media.uri(id); if (r != null) uris.add(r); }
      j.add({'uris': uris, 'text': unitCaption(v, u, pay, en: c['lang'] == 'en', terms: terms)});
    }
    jobs = j; done = 0; client = c; onDone = whenDone;
    notifyListeners();
    if (context.mounted) await next(context);
  }

  Future<void> next(BuildContext context) async {
    if (done >= jobs.length) return;
    final j = jobs[done];
    final r = await Native.sendWa(phone: client['p'] ?? '', text: j['text'] as String, uris: (j['uris'] as List).cast<String>());
    if (r == 'fail') { if (context.mounted) toast(context, '⚠️ مقدرتش أفتح الواتساب'); return; }
    done++;
    if (done >= jobs.length) { onDone?.call(); Future.delayed(const Duration(seconds: 2), () { jobs = []; notifyListeners(); }); }
    notifyListeners();
  }

  void cancel() { jobs = []; notifyListeners(); }
}

/// الشريط اللي تحت: «اتبعت 1 من 3 — ابعت 2»
class SendBar extends StatelessWidget {
  const SendBar({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: SendQ.I, builder: (context, _) {
        final q = SendQ.I;
        if (!q.active) return const SizedBox.shrink();
        final c = q.client;
        final who = (c['n'] ?? '').isNotEmpty ? c['n']! : ((c['p'] ?? '').isNotEmpty ? '+${c['p']}' : 'العميل');
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: kBd))),
          child: Row(children: [
            Expanded(child: Text('📤 $who — اتبعت ${q.done} من ${q.jobs.length}\nدوس إرسال في الواتساب وارجع هنا', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
            TextButton(onPressed: q.cancel, child: const Text('إلغاء')),
            FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)), onPressed: () => q.next(context), icon: const Icon(Icons.send, color: Colors.white), label: Text('ابعت ${q.done + 1}', style: const TextStyle(color: Colors.white))),
          ]),
        );
      });
}
