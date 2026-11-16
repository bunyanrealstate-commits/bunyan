/// ألبومات الموبايل: كل ألبوم = فيلا، والفيديوهات اللي جواه = شققها
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

class Media {
  static final _thumbs = <String, Uint8List?>{};
  static Future<bool> perm() async {
    if (kIsWeb) return false;
    final p = await PhotoManager.requestPermissionExtend(requestOption: const PermissionRequestOption(androidPermission: AndroidPermission(type: RequestType.video, mediaLocation: false)));
    return p.isAuth || p.hasAccess;
  }
  static Future<List<AssetPathEntity>> albums() async {
    if (!await perm()) return [];
    final l = await PhotoManager.getAssetPathList(type: RequestType.video, hasAll: false);
    final out = <AssetPathEntity>[];
    for (final a in l) { if (await a.assetCountAsync > 0) out.add(a); }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }
  static Future<AssetPathEntity?> album(String id) async { for (final a in await albums()) { if (a.id == id) return a; } return null; }
  static Future<List<AssetEntity>> videos(AssetPathEntity a) async { final n = await a.assetCountAsync; final l = await a.getAssetListRange(start: 0, end: n); l.sort((x, y) => x.createDateTime.compareTo(y.createDateTime)); return l; }
  static Future<AssetEntity?> byId(String id) async { try { return await AssetEntity.fromId(id); } catch (_) { return null; } }
  static Future<Uint8List?> thumb(String id, {int s = 300}) async {
    if (_thumbs.containsKey('$id@$s')) return _thumbs['$id@$s'];
    final a = await byId(id); final t = a == null ? null : await a.thumbnailDataWithSize(ThumbnailSize(s, s), quality: 80);
    _thumbs['$id@$s'] = t; return t;
  }
  /// content:// للفيديو علشان يتبعت على الواتساب
  static Future<String?> uri(String id) async { final a = await byId(id); return a == null ? null : await a.getMediaUrl(); }
  static String dur(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}
