import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/media.dart';
import 'theme.dart';

/// صورة مصغّرة لفيديو من الألبوم
class VThumb extends StatelessWidget {
  final String? id; final double w, h; final Widget? badge;
  const VThumb(this.id, {super.key, this.w = 86, this.h = 86, this.badge});
  @override
  Widget build(BuildContext context) {
    final box = ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: w, height: h, child: id == null
        ? Container(color: const Color(0xFFE6ECEF), child: const Icon(Icons.videocam_off_outlined, color: kMuted))
        : FutureBuilder<Uint8List?>(future: Media.thumb(id!), builder: (_, s) => s.data == null ? Container(color: const Color(0xFFE6ECEF), child: const Icon(Icons.movie_outlined, color: kMuted)) : Stack(fit: StackFit.expand, children: [Image.memory(s.data!, fit: BoxFit.cover), const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 30))]))));
    return badge == null ? box : Stack(children: [box, Positioned(top: 4, left: 4, child: badge!)]);
  }
}
