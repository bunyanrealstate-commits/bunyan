import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/media.dart';
import 'theme.dart';
import '../core/native.dart';

/// صورة مصغّرة لفيديو من الألبوم
/// يشغّل الفيديو في مشغّل الموبايل علشان تتأكد إنه هو
Future<void> playVideo(BuildContext context, String id) async {
  final u = await Media.uri(id);
  final ok = u != null && (await Native.ch.invokeMethod<bool>('play', {'uri': u}).catchError((_) => false) ?? false);
  if (!ok && context.mounted) toast(context, '⚠️ الفيديو مش موجود على الموبايل (اتمسح؟)');
}

class VThumb extends StatelessWidget {
  final String? id; final double w, h; final Widget? badge; final bool play;
  const VThumb(this.id, {super.key, this.w = 86, this.h = 86, this.badge, this.play = true});
  @override
  Widget build(BuildContext context) {
    final box = ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: w, height: h, child: id == null
        ? Container(color: const Color(0xFFE6ECEF), child: const Icon(Icons.videocam_off_outlined, color: kMuted))
        : FutureBuilder<Uint8List?>(future: Media.thumb(id!), builder: (_, s) => s.data == null ? Container(color: const Color(0xFFE6ECEF), child: const Icon(Icons.movie_outlined, color: kMuted)) : Stack(fit: StackFit.expand, children: [Image.memory(s.data!, fit: BoxFit.cover), const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 30))]))));
    final b = badge == null ? box : Stack(children: [box, Positioned(top: 4, left: 4, child: badge!)]);
    return play && id != null ? GestureDetector(onTap: () => playVideo(context, id!), child: b) : b;
  }
}
