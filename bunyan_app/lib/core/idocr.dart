/// 🪪 قراية الهوية/الرقم من الصورة على الموبايل نفسه (Google ML Kit — مجاني ومن غير نت ولا مفتاح)
/// نفس idText/mrz في القديم: رقم هوية الإمارات 784-…، الاسم، الجنسية، والسطور اللي ورا الكارت (MRZ)
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class IdOcr {
  static Future<String> text(String path) async {
    if (kIsWeb || path.isEmpty) return '';
    final r = TextRecognizer(script: TextRecognitionScript.latin);
    try { return (await r.processImage(InputImage.fromFilePath(path))).text; } finally { r.close(); }
  }

  static const iso3 = {'NLD': 'NETHERLANDS', 'EGY': 'EGYPT', 'IND': 'INDIA', 'PAK': 'PAKISTAN', 'PHL': 'PHILIPPINES', 'BGD': 'BANGLADESH', 'SYR': 'SYRIA', 'JOR': 'JORDAN', 'SDN': 'SUDAN', 'MAR': 'MOROCCO', 'LBN': 'LEBANON', 'YEM': 'YEMEN', 'IRQ': 'IRAQ', 'PSE': 'PALESTINE', 'TUN': 'TUNISIA', 'DZA': 'ALGERIA', 'SAU': 'SAUDI ARABIA', 'OMN': 'OMAN', 'NPL': 'NEPAL', 'LKA': 'SRI LANKA', 'NGA': 'NIGERIA', 'ETH': 'ETHIOPIA', 'KEN': 'KENYA', 'UGA': 'UGANDA', 'RUS': 'RUSSIA', 'GBR': 'UNITED KINGDOM', 'CHN': 'CHINA', 'IRN': 'IRAN', 'AFG': 'AFGHANISTAN', 'SOM': 'SOMALIA', 'ERI': 'ERITREA', 'DEU': 'GERMANY', 'FRA': 'FRANCE', 'ITA': 'ITALY', 'ESP': 'SPAIN', 'USA': 'UNITED STATES', 'CAN': 'CANADA', 'AUS': 'AUSTRALIA', 'TUR': 'TURKEY', 'UKR': 'UKRAINE', 'POL': 'POLAND', 'ROU': 'ROMANIA', 'BEL': 'BELGIUM', 'SWE': 'SWEDEN', 'IRL': 'IRELAND', 'ZAF': 'SOUTH AFRICA', 'BRA': 'BRAZIL', 'IDN': 'INDONESIA', 'VNM': 'VIETNAM', 'THA': 'THAILAND', 'KAZ': 'KAZAKHSTAN', 'UZB': 'UZBEKISTAN', 'CMR': 'CAMEROON', 'GHA': 'GHANA', 'LBY': 'LIBYA', 'KWT': 'KUWAIT', 'QAT': 'QATAR', 'BHR': 'BAHRAIN', 'ARE': 'UNITED ARAB EMIRATES'};
  static const natAr = {'egypt': 'مصر', 'egyptian': 'مصري', 'united arab emirates': 'الإمارات', 'uae': 'الإمارات', 'india': 'الهند', 'indian': 'هندي', 'pakistan': 'باكستان', 'pakistani': 'باكستاني', 'philippines': 'الفلبين', 'filipino': 'فلبيني', 'bangladesh': 'بنغلاديش', 'syria': 'سوريا', 'syrian': 'سوري', 'jordan': 'الأردن', 'jordanian': 'أردني', 'sudan': 'السودان', 'sudanese': 'سوداني', 'morocco': 'المغرب', 'moroccan': 'مغربي', 'lebanon': 'لبنان', 'lebanese': 'لبناني', 'yemen': 'اليمن', 'iraq': 'العراق', 'palestine': 'فلسطين', 'tunisia': 'تونس', 'algeria': 'الجزائر', 'saudi arabia': 'السعودية', 'oman': 'عُمان', 'nepal': 'نيبال', 'sri lanka': 'سريلانكا', 'nigeria': 'نيجيريا', 'ethiopia': 'إثيوبيا', 'kenya': 'كينيا', 'uganda': 'أوغندا', 'russia': 'روسيا', 'uk': 'بريطانيا', 'united kingdom': 'بريطانيا', 'china': 'الصين', 'iran': 'إيران', 'afghanistan': 'أفغانستان', 'somalia': 'الصومال', 'eritrea': 'إريتريا', 'netherlands': 'هولندا', 'germany': 'ألمانيا', 'france': 'فرنسا', 'italy': 'إيطاليا', 'spain': 'إسبانيا', 'united states': 'أمريكا', 'canada': 'كندا', 'australia': 'أستراليا', 'turkey': 'تركيا', 'ukraine': 'أوكرانيا'};

  static String _tc(String w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase();

  /// {en, id, nat_en, nat_ar}
  static Map<String, String> parse(String t) {
    final o = <String, String>{}; final fl = t.replaceAll(RegExp(r'\s+'), ' ');
    var m = RegExp(r'784[\s\-–.]*\d{4}[\s\-–.]*\d{7}[\s\-–.]*\d').firstMatch(fl);
    if (m != null) { final d = m[0]!.replaceAll(RegExp(r'\D'), ''); if (d.length == 15) o['id'] = '${d.substring(0, 3)}-${d.substring(3, 7)}-${d.substring(7, 14)}-${d.substring(14)}'; }
    if (o['id'] == null) { m = RegExp(r'\b[A-Z]{1,2}\d{6,9}\b').firstMatch(fl); if (m != null) o['id'] = m[0]!; }
    m = RegExp(r"Name\s*[:：.]?\s*([A-Z][A-Za-z' \-]{3,60})").firstMatch(t);
    if (m != null) o['en'] = m[1]!.replaceAll(RegExp(r'\b(Date|Sex|Nationality|Birth|Card|Number|Signature).*$', caseSensitive: false), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    m = RegExp(r'Nationality\s*[:：.]?\s*([A-Za-z ]{3,30})').firstMatch(t);
    if (m != null) o['nat_en'] = m[1]!.trim().split(RegExp(r'\s{2,}|\n')).first;
    // السطور اللي ورا الكارت (MRZ) — أدق مصدر للاسم والجنسية والرقم
    for (final x0 in t.split('\n')) {
      final x = x0.toUpperCase().replaceAll(RegExp(r'\s+'), '').replaceAll(RegExp('[«‹]'), '<');
      if (x.length < 20 || !x.contains('<')) continue;
      if (RegExp(r'^[A-Z<]+$').hasMatch(x) && x.indexOf('<<') > 0 && !RegExp(r'^I[A-Z<]ARE').hasMatch(x)) {
        final pr = x.split('<<'); final sur = pr[0].replaceAll('<', ' ').trim(), giv = (pr.length > 1 ? pr[1] : '').replaceAll('<', ' ').trim();
        if (sur.isNotEmpty && giv.isNotEmpty) o['en'] = '$giv $sur'.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).map(_tc).join(' ');
      }
      final mm = RegExp(r'^\d{6}\d[MF<]\d{6}\d([A-Z]{3})').firstMatch(x);
      if (mm != null && iso3[mm[1]] != null) o['nat_en'] = iso3[mm[1]]!;
      if (o['id'] == null) { final mi = RegExp(r'^I[A-Z<]ARE\d{9}\d?(784\d{12})').firstMatch(x); if (mi != null) { final d = mi[1]!; o['id'] = '${d.substring(0, 3)}-${d.substring(3, 7)}-${d.substring(7, 14)}-${d.substring(14)}'; } }
    }
    if (o['en'] != null) o['en'] = o['en']!.split(' ').where((w) => w.isNotEmpty).map(_tc).join(' ');
    if (o['nat_en'] != null) o['nat_ar'] = natAr[o['nat_en']!.toLowerCase()] ?? '';
    return o;
  }

  static String phone(String t) {
    final m = t.replaceAllMapped(RegExp('[٠-٩]'), (x) => '${'٠١٢٣٤٥٦٧٨٩'.indexOf(x[0]!)}').replaceAll('\n', ' ').split(' ').join(' ');
    final r = RegExp(r'\+?\d[\d\s\-()]{7,16}\d').firstMatch(m);
    return r == null ? '' : r[0]!.replaceAll(RegExp(r'[\s\-()]'), '');
  }
}
